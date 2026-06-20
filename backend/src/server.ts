/**
 * Reonic energy-assistant backend — REST for the iOS app.
 * Endpoints map 1:1 to homescreen-and-backend.md §5. Numbers come from tools; words come later.
 */
import express from "express";
import { households, household, contract, tariff, recordsArray, indexOf } from "./data";
import { resolveNow } from "./clock";
import { devicesFor, deviceById } from "./devices";
import { optimizeLoad } from "./optimizeLoad";
import { moneyForecast } from "./money";
import { commitmentsFor, addCommitment, clearCommitments } from "./ledger";
import { snapshotFor, insightsFor } from "./views";
import { runChat } from "./openaiChat";
import { planDay, PlanTaskInput } from "./planDay";

const PORT = parseInt(process.env.PORT || "8090", 10);
const HOST = "127.0.0.1";
const app = express();
app.use(express.json());

const hid = (req: express.Request) => (req.query.household as string) || (req.body?.household as string) || "HH-1001";
const clk = (req: express.Request) => (req.query.clock as string) || (req.body?.clock as string);

app.get("/health", (_req, res) => res.json({ status: "ok", households: households().length }));

// GET now / state — the glance snapshot
function nowHandler(req: express.Request, res: express.Response) {
    const s = snapshotFor(hid(req), resolveNow(clk(req), req.query.at as string)) as any;
    return s.error ? res.status(404).json(s) : res.json(s);
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

// POST plan_day — schedule several tasks at once; computes AND commits to the shared ledger
app.post("/plan_day", (req, res) => {
    try {
        const id = hid(req);
        const now = resolveNow(clk(req), req.body.at);
        const mode = (req.body.mode as string) || "cheapest";
        const tasks = Array.isArray(req.body.tasks) ? (req.body.tasks as PlanTaskInput[]) : [];
        if (!tasks.length) return res.status(400).json({ error: "tasks required" });
        if (!["cheapest", "greenest", "soonest"].includes(mode)) return res.status(400).json({ error: "bad mode" });
        res.json(planDay(id, now, mode as any, tasks));
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
    res.json(insightsFor(hid(req), resolveNow(clk(req), req.query.at as string)));
});

// POST chat — grounded assistant (OpenAI function-calling over the planner tools)
app.post("/chat", async (req, res) => {
    const token = process.env.CHAT_TOKEN;
    if (token && req.get("x-lumen-token") !== token) return res.status(401).json({ error: "unauthorized" });
    const message = String(req.body?.message || "").slice(0, 1000);
    if (!message) return res.status(400).json({ error: "message required" });
    try {
        const out = await runChat(hid(req), clk(req), message, Array.isArray(req.body?.history) ? req.body.history : []);
        res.json(out);
    } catch (e: any) {
        res.status(e.code === 503 ? 503 : 500).json({ error: String(e.message || e) });
    }
});

app.listen(PORT, HOST, () => console.log(`reonic-backend on http://${HOST}:${PORT}`));

// helpers
function windowOf(id: string, startISO: string, durationSlots: number): string {
    const recs = recordsArray(id); const s = indexOf(id, startISO);
    const e = recs[Math.min(recs.length - 1, s + durationSlots)].timestamp;
    return `${startISO.slice(11, 16)}–${e.slice(11, 16)}`;
}
function round(v: number, dp: number): number { const f = 10 ** dp; return Math.round(v * f) / f; }
