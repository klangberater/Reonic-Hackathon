/**
 * Reonic energy-assistant backend — REST for the iOS app.
 * Endpoints map 1:1 to homescreen-and-backend.md §5. Numbers come from tools; words come later.
 */
import express from "express";
import {
    households, household, contract, tariff, billsFor, insightsFor,
    recordAt, recordsArray, indexOf,
} from "./data";
import { resolveNow } from "./clock";
import { devicesFor, deviceById } from "./devices";
import { optimizeLoad } from "./optimizeLoad";
import { moneyForecast } from "./money";
import { commitmentsFor, addCommitment, clearCommitments } from "./ledger";

const PORT = parseInt(process.env.PORT || "8090", 10);
const HOST = "127.0.0.1";
const app = express();
app.use(express.json());

const hid = (req: express.Request) => (req.query.household as string) || (req.body?.household as string) || "HH-1001";
const clk = (req: express.Request) => (req.query.clock as string) || (req.body?.clock as string);

app.get("/health", (_req, res) => res.json({ status: "ok", households: households().length }));

// GET now / state — the glance snapshot (tool get_current_state)
function snapshot(id: string, at: string) {
    const r = recordAt(id, at);
    if (!r) return null;
    const batteryState = r.battery_charge_kw > 0.05 ? "charging" : r.battery_discharge_kw > 0.05 ? "discharging" : "idle";
    const gridDir = r.grid_export_kw > 0.05 ? "exporting" : r.grid_import_kw > 0.05 ? "importing" : "balanced";
    const status = r.grid_export_kw > 0.05 ? "exporting_surplus" : r.grid_import_kw > 0.05 ? "drawing_grid" : "self_powered";
    return {
        household_id: id, household_name: household(id).name, at,
        outdoor_temp_c: r.outdoor_temp_c, solar_kw: r.pv_production_kw, consumption_kw: r.total_consumption_kw,
        breakdown_kw: { house: r.house_load_kw, heatpump: r.heatpump_kw, ev: r.ev_charging_kw },
        battery: { soc_pct: r.battery_soc_pct, flow_kw: round(r.battery_charge_kw - r.battery_discharge_kw, 3), state: batteryState },
        grid: { flow_kw: round(r.grid_export_kw - r.grid_import_kw, 3), direction: gridDir },
        price_eur_per_kwh: r.price_eur_per_kwh, net_kw: round(r.pv_production_kw - r.total_consumption_kw, 3), status,
    };
}
function nowHandler(req: express.Request, res: express.Response) {
    const s = snapshot(hid(req), resolveNow(clk(req), req.query.at as string));
    return s ? res.json(s) : res.status(404).json({ error: "no record at that time" });
}
app.get("/now", nowHandler);
app.get("/state", nowHandler);

// GET household — asset profile
app.get("/household", (req, res) => {
    const id = hid(req); const h = household(id); const c = contract(id);
    res.json({
        household_id: id, name: h.name, city: h.city, residents: h.residents,
        pv_kwp: h.pv_kwp, battery_kwh: h.battery_kwh, battery_power_kw: h.battery_power_kw,
        heat_pump: h.heat_pump, ev_charger: h.ev_charger, ev_battery_kwh: c.assets.ev_battery_kwh,
        tariff: tariff(h.tariff_id),
    });
});

// GET money — forecast
app.get("/money", (req, res) => {
    try { res.json(moneyForecast(hid(req), resolveNow(clk(req), req.query.at as string))); }
    catch (e: any) { res.status(400).json({ error: String(e.message || e) }); }
});

// GET devices — library + EV + current commitment status
app.get("/devices", (req, res) => {
    const id = hid(req);
    const committed = commitmentsFor(id);
    res.json(devicesFor(id).map((d) => {
        const c = committed.find((x) => x.device === d.id);
        return {
            id: d.id, name: d.name, icon: d.icon, energy_kwh: round(d.energyKwh, 2),
            power_kw: round(d.powerKw, 2), controllable: d.controllable,
            status: c ? "scheduled" : "idle",
            scheduled: c ? { start: c.startISO, window: windowOf(id, c.startISO, c.durationSlots), source: c.source } : null,
        };
    }));
});

// GET optimize_load — recommended window, source, ribbon, rationale (one call, three surfaces)
app.get("/optimize_load", (req, res) => {
    try {
        const id = hid(req);
        const d = deviceById(id, req.query.device as string);
        res.json(optimizeLoad(id, d, resolveNow(clk(req), req.query.at as string), req.query.deadline as string));
    } catch (e: any) { res.status(400).json({ error: String(e.message || e) }); }
});

// POST commit_load — add to the ledger (next device routes around it)
app.post("/commit_load", (req, res) => {
    try {
        const id = hid(req);
        const d = deviceById(id, req.body.device);
        const now = resolveNow(clk(req), req.body.at);
        const plan = req.body.start
            ? { start: req.body.start as string, source: "free" as const }
            : (() => { const p = optimizeLoad(id, d, now, req.body.deadline); return { start: p.start, source: p.source }; })();
        const startIdx = indexOf(id, plan.start);
        if (startIdx < 0) return res.status(400).json({ error: "invalid start" });
        addCommitment({ householdId: id, device: d.id, deviceName: d.name, startISO: plan.start, startIdx, durationSlots: d.durationSlots, powerKw: d.powerKw, source: plan.source });
        res.json({ committed: true, device: d.id, start: plan.start, window: windowOf(id, plan.start, d.durationSlots), commitments: commitmentsFor(id).length });
    } catch (e: any) { res.status(400).json({ error: String(e.message || e) }); }
});

app.get("/commitments", (req, res) => res.json(commitmentsFor(hid(req))));
app.post("/reset", (req, res) => { clearCommitments(hid(req)); res.json({ ok: true }); });

// GET insights — date-aware; drives the health indicator + proactive cards
app.get("/insights", (req, res) => {
    const id = hid(req);
    const nowDate = resolveNow(clk(req), req.query.at as string).slice(0, 10);
    const events = insightsFor(id).map((e) => ({ ...e, active: isActive(e.period, nowDate) }));
    const health = events.some((e) => e.active && e.type === "anomaly" && e.severity === "high") ? "alert" : "ok";
    res.json({ health, events });
});

app.listen(PORT, HOST, () => console.log(`reonic-backend on http://${HOST}:${PORT}`));

// helpers
function windowOf(id: string, startISO: string, durationSlots: number): string {
    const recs = recordsArray(id); const s = indexOf(id, startISO);
    const e = recs[Math.min(recs.length - 1, s + durationSlots)].timestamp;
    return `${startISO.slice(11, 16)}–${e.slice(11, 16)}`;
}
function isActive(period: string, nowDate: string): boolean {
    if (period === "recurring") return true;
    const range = period.match(/^(\d{4}-\d{2}-\d{2})\.\.(\d{4}-\d{2}-\d{2})$/);
    if (range) {
        const end = new Date(range[2]); end.setDate(end.getDate() + 7); // stays relevant a week after
        return nowDate >= range[1] && nowDate <= end.toISOString().slice(0, 10);
    }
    if (/^\d{4}-\d{2}$/.test(period)) return period <= nowDate.slice(0, 7); // retrospective monthly insight
    return false;
}
function round(v: number, dp: number): number { const f = 10 ** dp; return Math.round(v * f) / f; }
