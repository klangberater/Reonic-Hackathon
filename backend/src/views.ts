/** Shared read-models used by both the REST handlers and the chat tool-loop. */
import { recordAt, household, insightsFor as rawInsights } from "./data";

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

export function insightsFor(id: string, at: string) {
    const nowDate = at.slice(0, 10);
    const events = rawInsights(id).map((e) => ({ ...e, active: isActive(e.period, nowDate) }));
    const health = events.some((e) => e.active && e.type === "anomaly" && e.severity === "high") ? "alert" : "ok";
    return { health, events };
}

export function isActive(period: string, nowDate: string): boolean {
    if (period === "recurring") return true;
    const range = period.match(/^(\d{4}-\d{2}-\d{2})\.\.(\d{4}-\d{2}-\d{2})$/);
    if (range) {
        const end = new Date(range[2]); end.setDate(end.getDate() + 7);
        return nowDate >= range[1] && nowDate <= end.toISOString().slice(0, 10);
    }
    if (/^\d{4}-\d{2}$/.test(period)) return period <= nowDate.slice(0, 7);
    return false;
}

function round(v: number, dp: number): number { const f = 10 ** dp; return Math.round(v * f) / f; }
