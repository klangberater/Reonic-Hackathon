# `data/` — demo-ready dataset (derived)

**Do not hand-edit.** This directory is generated from the raw Enpal dataset in
`../enpal-track-dataset/` by `../scripts/transform_dataset.py`. To regenerate:

```bash
python3 scripts/transform_dataset.py
```

## Why this exists

The raw Enpal dataset is *illustrative* (organizer's word) and has its `outdoor_temp_c`
and `heatpump_kw` channels **seasonally inverted** relative to PV/price/calendar — its
"June" is a freezing, heat-pump-blasting winter that happens to be sunny. The transform
rebuilds the physically-driven channels so the whole year is coherent and anchors the
demo to **this weekend (2026-06-20/21)**.

## What the transform does

1. **Year shift 2025 → 2026** on every timestamp (lands the data's 06-20/21 on the demo weekend).
2. **Rebuilds `outdoor_temp_c`** as a clean seasonal + diurnal curve (cold Jan, warm Jul), with
   small per-city offsets.
3. **Overlays the real Munich forecast** (`munich_forecast_2026-06-20.json`, fetched from
   Open-Meteo) on HH-1001's now-window — so the on-screen temperature matches what is literally
   outside during judging (a genuine 21–34 °C heatwave).
4. **Recomputes `heatpump_kw`** from temperature (heavy when cold, ~0 in summer; calibrated to a
   realistic ~1.5 kW average on a 0 °C day for a 9 kW system; 0 for HH-1004 which has no heat pump).
5. **Injects a winter heat-pump anomaly** (~+60%) for HH-1001 in a genuinely cold week
   (2026-01-12..19) — a real, detectable anomaly to drive the proactive-nudge demo.
6. **Recomputes `total_consumption_kw`** and **re-runs a greedy self-consumption battery+grid
   dispatch**, so the energy balance `pv + import + discharge = consumption + export + charge`
   holds to floating-point precision at every step.
7. **Recomputes `monthly_bills.json`** from the new dispatch, **realigns `insight_events.json`**
   (anomaly week, cheapest-price hour, highest-bill month), and year-shifts `dynamic_prices.json`
   and `contracts.json` (including the hardcoded dates inside `contract_terms_text`).

Kept unchanged from raw (these already track the calendar correctly): `pv_production_kw`,
`house_load_kw`, `ev_charging_kw`, `price_eur_per_kwh`.

## Sanity figures (HH-1001, the hero home)

- Annual consumption ≈ 12,780 kWh (heat pump ≈ 5,970 · EV ≈ 3,020 · household), annual bill ≈ €2,700.
- Winter Jan ≈ €667 · summer June ≈ **−€12** (feed-in beats import — the home *earns* money).
- Anomaly week heat-pump draw 2.25 kW vs 1.39 kW normal = **+61%**.
- Max energy-balance error across all 4 homes × 35,040 steps: ~1e-15 kW.
