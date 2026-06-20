/**
 * Reonic energy-assistant backend.
 * Minimal but real: /health for deploy smoke tests, and /state computing the live
 * snapshot (tool #1 get_current_state) from the coherent dataset. Behind nginx at
 * https://getfletcher.ai/api/ (the /api/ prefix is stripped by the proxy).
 */
import express from "express";
import { households, household, seriesByTimestamp } from "./data";

const PORT = parseInt(process.env.PORT || "8090", 10);
const HOST = "127.0.0.1"; // fronted by nginx; never bind publicly

// Demo clock: one switch flips "now" between the summer heatwave weekend and a winter day.
const CLOCKS: Record<string, string> = {
  summer: "2026-06-20T13:00:00",
  winter: "2026-01-15T08:00:00",
};
function resolveNow(clock?: string, at?: string): string {
  if (at) return at;
  return CLOCKS[clock || process.env.DEMO_CLOCK || "summer"] || CLOCKS.summer;
}

const app = express();

app.get("/health", (_req, res) => {
  res.json({ status: "ok", households: households().length });
});

// tool #1 — get_current_state (the glance). Returns numbers; words come later from Claude.
app.get("/state", (req, res) => {
  try {
    const id = (req.query.household as string) || "HH-1001";
    const at = resolveNow(req.query.clock as string, req.query.at as string);
    const r = seriesByTimestamp(id).get(at);
    if (!r) return res.status(404).json({ error: `no record at ${at}` });

    const net = r.pv_production_kw - r.total_consumption_kw;
    const batteryState =
      r.battery_charge_kw > 0.05 ? "charging" : r.battery_discharge_kw > 0.05 ? "discharging" : "idle";
    const gridDir =
      r.grid_export_kw > 0.05 ? "exporting" : r.grid_import_kw > 0.05 ? "importing" : "balanced";
    const status =
      r.grid_export_kw > 0.05 ? "exporting_surplus" : r.grid_import_kw > 0.05 ? "drawing_grid" : "self_powered";

    res.json({
      household_id: id,
      household_name: household(id).name,
      at,
      outdoor_temp_c: r.outdoor_temp_c,
      solar_kw: r.pv_production_kw,
      consumption_kw: r.total_consumption_kw,
      breakdown_kw: { house: r.house_load_kw, heatpump: r.heatpump_kw, ev: r.ev_charging_kw },
      battery: { soc_pct: r.battery_soc_pct, flow_kw: r.battery_charge_kw - r.battery_discharge_kw, state: batteryState },
      grid: { flow_kw: r.grid_export_kw - r.grid_import_kw, direction: gridDir },
      price_eur_per_kwh: r.price_eur_per_kwh,
      net_kw: Math.round(net * 1000) / 1000,
      status,
    });
  } catch (e: any) {
    res.status(400).json({ error: String(e.message || e) });
  }
});

app.listen(PORT, HOST, () => {
  console.log(`reonic-backend listening on http://${HOST}:${PORT}`);
});
