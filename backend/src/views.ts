/** Shared read-models used by both the REST handlers and the chat tool-loop. */
import { recordAt, recordsArray, household, billsFor } from "./data";
import { detectHeatpumpAnomaly } from "./anomaly";

interface InsightEvent {
    type: string; severity: string; period: string;
    title: string; detail: string; suggested_action: string; active: boolean;
}

export function snapshotFor(id: string, at: string) {
    const r = recordAt(id, at);
    if (!r) return { error: `no record at ${at}` };
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

/**
 * Live insights — computed from the timeseries/bills, not a fixture.
 * The anomaly is detected + weather-normalised (anomaly.ts); the nudge and the
 * highest-bill note are simple live aggregations. Drives the health chip + cards.
 */
export function insightsFor(id: string, at: string) {
    const nowDate = at.slice(0, 10);
    const events: InsightEvent[] = [];

    const anomaly = detectHeatpumpAnomaly(id, at);
    if (anomaly) {
        events.push({
            type: "anomaly", severity: "high", period: anomaly.period,
            title: `Heat pump using ~${Math.round(anomaly.pctOver)}% more than usual`,
            detail: anomaly.detail,
            suggested_action: "Check heat pump settings / book a service inspection.",
            active: true, // detection only returns a still-active run
        });
    }

    const nudge = cheapestHourNudge(id, at);
    if (nudge) events.push(nudge);

    const bill = highestBillInsight(id, nowDate);
    if (bill) events.push(bill);

    const health = events.some((e) => e.active && e.type === "anomaly" && e.severity === "high") ? "alert" : "ok";
    return { health, events };
}

/** Cheapest hour-of-day over the trailing week — "shift flexible loads here". */
function cheapestHourNudge(id: string, at: string): InsightEvent | null {
    const recs = recordsArray(id);
    const start = new Date(Date.parse(at) - 7 * 86_400_000).toISOString().slice(0, 10);
    const nowDate = at.slice(0, 10);
    const sum = new Array(24).fill(0), cnt = new Array(24).fill(0);
    for (const r of recs) {
        const d = r.timestamp.slice(0, 10);
        if (d < start || d > nowDate) continue;
        const h = +r.timestamp.slice(11, 13);
        sum[h] += r.price_eur_per_kwh; cnt[h]++;
    }
    let bestH = -1, bestAvg = Infinity;
    for (let h = 0; h < 24; h++) {
        if (!cnt[h]) continue;
        const avg = sum[h] / cnt[h];
        if (avg < bestAvg) { bestAvg = avg; bestH = h; }
    }
    if (bestH < 0) return null;
    const hh = String(bestH).padStart(2, "0");
    return {
        type: "nudge", severity: "info", period: "recurring",
        title: `Cheapest power is around ${hh}:00`,
        detail: `Over the last week the lowest average price was at ${hh}:00 (~€${bestAvg.toFixed(3)}/kWh). Shift flexible loads (EV, dishwasher, laundry) into this window.`,
        suggested_action: "Schedule EV charging and appliances into the cheapest window.",
        active: true,
    };
}

/** Highest monthly bill so far this year — context for "why was my bill high". */
function highestBillInsight(id: string, nowDate: string): InsightEvent | null {
    const nowMonth = nowDate.slice(0, 7);
    const past = billsFor(id).filter((b) => b.month <= nowMonth);
    if (past.length < 2) return null;
    const hi = past.reduce((a, b) => (b.total_bill_eur > a.total_bill_eur ? b : a));
    const lo = past.reduce((a, b) => (b.total_bill_eur < a.total_bill_eur ? b : a));
    if (hi.month === lo.month) return null;
    return {
        type: "insight", severity: "info", period: hi.month,
        title: `Highest bill in ${hi.month}`,
        detail: `${hi.month} cost €${hi.total_bill_eur.toFixed(2)} vs your low of €${lo.total_bill_eur.toFixed(2)} in ${lo.month}, driven by heating demand and lower solar.`,
        suggested_action: "Pre-heat during cheap/sunny hours; review winter heating schedule.",
        active: hi.month <= nowMonth,
    };
}

function round(v: number, dp: number): number { const f = 10 ** dp; return Math.round(v * f) / f; }
