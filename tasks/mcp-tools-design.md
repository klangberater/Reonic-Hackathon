# MCP Tools Design — Energy Assistant

**Principle:** tools return numbers, the model returns words. Every figure the model may
quote comes from a tool. No free-form arithmetic by the LLM.

## Conventions
- `household_id` defaults to `"HH-1001"` (hero home). All tools accept it.
- **Demo clock** is injectable. Two contexts:
  - Summer now: `2026-06-20T13:00:00` (Sat, solar peaking, price cheap) — primary glance.
  - Winter day: a mid-Jan 2026 timestamp (cold, heat pump heavy) — anomaly/forecast story.
- Energy in **kWh** at tool boundaries (records are kW → ×0.25). Money in **€**.
- Every tool returns flat `{...numbers, basis:{...}}`; `basis` carries raw figures safe to quote.
- Data source: `data/` (the coherent, demo-anchored dataset).

## Decisions (locked 2026-06-20)
1. **Anomaly = precomputed** for demo safety → dedicated `get_insights` reading `insight_events.json`.
   `get_energy_summary` still computes deltas live for ad-hoc drill-down.
2. **Include `get_contract`** (contract intelligence is its own scope area, cheap, good judge moment).
3. **`simulate_appliance_run` uses the opportunity-cost-of-feed-in model** (see tool 5).

## Open follow-up
- `insight_events.json` currently holds only the WINTER set. Add a SUMMER set (earned-money month,
  high midday export → shift EV/loads) so the June glance has date-appropriate proactive content.
  `get_insights` must be **date-aware** (return insights whose period brackets / precedes the clock).

---

## The 7 tools

### 1. get_current_state(household_id?, at?) → Moment #1 (glance)
Live snapshot at `at`: outdoor_temp_c, solar_kw, consumption_kw + breakdown{house,heatpump,ev},
battery{soc_pct,flow_kw,state}, grid{flow_kw,direction}, price_eur_per_kwh, net_kw,
status: "exporting_surplus"|"self_powered"|"drawing_grid". Reads one timeseries record.

### 2. get_energy_summary(household_id?, device, start, end, compare_to_prior?) → "why is my bill high?" + live anomaly math
device: all|solar|house|heatpump|ev|battery|grid. Returns produced/consumed/imported/exported_kwh,
self_sufficiency_pct, cost_eur, and optional prior{consumed_kwh,cost_eur,delta_pct}. The live
anomaly engine (e.g. heatpump week vs prior week).

### 3. get_prices(household_id?, start, end) → tariff intelligence + Moment #2 input
tariff_type, series[{hour,price}] (forward strip), cheapest, most_expensive, current_vs_avg_pct,
fixed_rate (HH-1003), savings_vs_other_tariff_eur. Reads dynamic_prices.json + tariffs.json.

### 4. forecast_bill(household_id?, month?) → Moment #3 (forecast)
month, days_elapsed/total, cost_to_date_eur, projected_total_eur (to-date + run-rate),
vs_standard_tariff_eur, vs_last_month_eur. "On track for €87."

### 5. simulate_appliance_run(household_id?, appliance, candidates?, energy_kwh?, duration_min?, max_power_kw?) → THE MONEY TOOL (Moment #2)
appliance: dishwasher|washing_machine|ev_charge|custom. Returns options[{start, cost_eur,
solar_covered_kwh, battery_kwh, grid_kwh}] and recommended{start, cost_eur, saves_vs_now_eur}.
**Cost model (marginal):** load drawn during solar SURPLUS costs the lost feed-in (~€0.081/kWh
opportunity cost); load drawn during a DEFICIT costs the grid price at that hour. That asymmetry
is what makes "1pm beats 7pm by €0.42" true and defensible.

### 6. get_contract(household_id?) → "is this still a good deal?"
tariff_name, model, rate_basis, feed_in, contract_end, notice_deadline, days_until_notice,
est_annual_cost_eur, est_annual_cost_other_tariff_eur, terms_text (raw, for the model to quote).
Reads contracts.json (free-text field is explicitly there for this).

### 7. get_insights(household_id?, as_of?) → precomputed proactive nudges (Moment #3, demo-safe)
Date-aware. Returns the seeded anomalies/nudges/insights relevant to `as_of` from
insight_events.json (winter: heat-pump anomaly + bill spike; summer: earned-money + export nudge
once added).

---

## Build order at kickoff
1. Scaffold MCP server (Node/TS) with a thin data-access layer over `data/` (load + index by household).
2. Implement tools 1, 3, 5 first (the glance + the decision = the two flashiest moments).
3. Then 2, 4, 6, 7.
4. Add the summer insight set to the transform + `get_insights` date-awareness.
5. Wire Claude → tools → get the 3 demo answers reliable before any UI polish.
