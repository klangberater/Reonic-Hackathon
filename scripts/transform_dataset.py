#!/usr/bin/env python3
"""
Transform the illustrative Enpal dataset into a physically-coherent, demo-ready dataset.

Why this exists: the raw data in `enpal-track-dataset/` has its `outdoor_temp_c` and
`heatpump_kw` channels seasonally INVERTED relative to PV/price/calendar (its "June" is a
freezing, heat-pump-blasting winter that happens to be sunny). This script rebuilds the
physically-driven channels from scratch so the whole year is coherent, then anchors the
"now" weekend (2026-06-20/21) to the REAL Munich forecast.

Pipeline per household:
  1. Shift timestamps 2025 -> 2026 (lands 06-20/21 on the demo weekend for free).
  2. Regenerate outdoor_temp_c: seasonal (cold Jan, warm Jul) + diurnal, per-city offset.
  3. Overlay the real Munich forecast on HH-1001's now-window.
  4. Recompute heatpump_kw from temperature (heavy when cold, ~0 in summer; per-home cap).
  5. Inject a winter heat-pump anomaly (~+60%) for HH-1001 in a genuinely cold week.
  6. total_consumption = house_load + heatpump + ev_charging.
  7. Greedy self-consumption battery+grid dispatch -> energy balance holds by construction.
Then recompute monthly_bills, realign insight_events, year-shift prices & contracts.

Keep PV, house_load, ev_charging, price from the raw data (those track the calendar fine).
Raw data is never modified; everything is written to ./data/.
"""
import json, math, os, re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "enpal-track-dataset")
OUT = os.path.join(ROOT, "data")
DT = 0.25  # hours per 15-min step
YEAR_SHIFT = 1  # 2025 -> 2026

# Per-city mean-temperature offset (deg C) vs the base German curve. Munich = continental.
CITY_OFFSET = {"Munich": 0.0, "Hamburg": -1.0, "Cologne": 1.0, "Berlin": -0.5}

# Winter anomaly window for HH-1001 (genuinely cold after re-sim) and its multiplier.
ANOMALY_HH = "HH-1001"
ANOMALY_START = "2026-01-12"
ANOMALY_END = "2026-01-19"
ANOMALY_MULT = 1.6


def shift_year(ts: str) -> str:
    """'2025-06-20T13:00:00' -> '2026-06-20T13:00:00' (handles Feb 29 safely: none in 2025)."""
    return str(int(ts[:4]) + YEAR_SHIFT) + ts[4:]


def jitter(i: int, scale: float) -> float:
    """Deterministic, repeatable pseudo-noise in [-scale, +scale] from the record index."""
    h = (i * 2654435761) & 0xFFFFFFFF
    return ((h % 10000) / 10000.0 - 0.5) * 2.0 * scale


def seasonal_temp(day_of_year: float, hour: float, city: str, i: int) -> float:
    """Clean seasonal + diurnal outdoor temperature. Coldest ~mid-Jan, warmest ~mid-Jul."""
    # Seasonal: cosine peaking mid-Jul (day ~197), trough mid-Jan. +cos so summer is WARM.
    season = math.cos(2 * math.pi * (day_of_year - 197) / 365.0)
    seasonal = 10.0 + 9.5 * season
    # Diurnal: coldest ~04:00, warmest ~16:00; swing wider in summer.
    amp = 3.5 + 3.0 * max(0.0, season)
    diurnal = amp * math.sin(2 * math.pi * (hour - 10) / 24.0)
    return round(seasonal + diurnal + CITY_OFFSET.get(city, 0.0) + jitter(i, 0.6), 1)


def heatpump_from_temp(temp: float, hp_cap: float, i: int) -> float:
    """Electrical input of the heat pump as a function of outdoor temp.
    Heating ramps in below 15C, reaching ~cap near -7C. Small year-round DHW baseload."""
    if hp_cap <= 0:
        return 0.0
    dhw = 0.08 + max(0.0, jitter(i, 0.05))  # domestic hot water, always on
    if temp >= 15.0:
        heating = 0.0
    else:
        # Electrical draw ~ k*(setpoint - temp). k scales with system size; the heat-pump
        # nameplate kW is a PEAK, so realistic average draw is a small fraction of it
        # (duty cycle + COP). Calibrated to ~1.5 kW avg on a 0 C day for a 9 kW system.
        k = hp_cap * 0.010
        heating = min(k * (15.0 - temp), hp_cap * 0.40)
    return round(dhw + heating + max(0.0, jitter(i, 0.03)), 3)


def load_forecast_15min():
    """Load Munich forecast (hourly) and return a function day->list won't fit; instead return
    an interpolator over the now-window keyed by 'YYYY-MM-DDTHH:MM:SS' timestamps (2026 frame)."""
    p = os.path.join(OUT, "munich_forecast_2026-06-20.json")
    fc = json.load(open(p))
    times = fc["hourly"]["time"]          # ['2026-06-20T00:00', ...] hourly
    temps = fc["hourly"]["temperature_2m"]
    # minutes-since-window-start -> temp, for linear interpolation
    base = times[0]  # 2026-06-20T00:00
    pts = []
    for t, v in zip(times, temps):
        # minutes from base
        d = (int(t[8:10]) - int(base[8:10])) * 1440 + int(t[11:13]) * 60 + int(t[14:16])
        pts.append((d, v))
    window_dates = {t[:10] for t in times}

    def interp(ts: str):
        """ts is a 2026-frame 15-min timestamp; return forecast temp or None if outside window."""
        if ts[:10] not in window_dates:
            return None
        mins = (int(ts[8:10]) - int(base[8:10])) * 1440 + int(ts[11:13]) * 60 + int(ts[14:16])
        for k in range(len(pts) - 1):
            d0, v0 = pts[k]
            d1, v1 = pts[k + 1]
            if d0 <= mins <= d1:
                f = (mins - d0) / (d1 - d0) if d1 != d0 else 0
                return round(v0 + (v1 - v0) * f + jitter(mins, 0.2), 1)
        return round(pts[-1][1], 1)
    return interp


def dispatch_step(pv, cons, soc, cap, pmax):
    """Greedy self-consumption. Returns (charge, discharge, imp, exp, new_soc)."""
    net = pv - cons
    charge = discharge = imp = exp = 0.0
    if cap <= 0 or pmax <= 0:
        if net >= 0:
            exp = net
        else:
            imp = -net
        return 0.0, 0.0, imp, exp, 0.0
    if net > 0:  # surplus -> charge then export
        charge = min(net, pmax, (cap - soc) / DT)
        charge = max(0.0, charge)
        soc += charge * DT
        exp = net - charge
    else:  # deficit -> discharge then import
        need = -net
        discharge = min(need, pmax, soc / DT)
        discharge = max(0.0, discharge)
        soc -= discharge * DT
        imp = need - discharge
    return charge, discharge, imp, exp, soc


def transform_household(hh, contracts_by_id, forecast):
    hid = hh["household_id"]
    city = hh["city"]
    cap = hh["battery_kwh"]
    pmax = hh["battery_power_kw"]
    hp_cap = contracts_by_id[hid]["assets"].get("heat_pump_kw", 0.0)

    raw = json.load(open(os.path.join(RAW, hh["timeseries_file"])))
    recs = raw["records"]
    out = []
    soc = (cap * 0.5) if cap > 0 else 0.0  # start mid-charge
    max_balance_err = 0.0

    for i, r in enumerate(recs):
        ts = shift_year(r["timestamp"])
        # day-of-year + hour for the seasonal model
        mo, da = int(ts[5:7]), int(ts[8:10])
        doy = (mo - 1) * 30.4 + da
        hour = int(ts[11:13]) + int(ts[14:16]) / 60.0

        # --- temperature: real forecast on the now-window (HH-1001 = Munich), else model
        temp = None
        if hid == ANOMALY_HH:
            temp = forecast(ts)
        if temp is None:
            temp = seasonal_temp(doy, hour, city, i)

        # --- heat pump (with winter anomaly injection for the hero home)
        hp = heatpump_from_temp(temp, hp_cap, i)
        if hid == ANOMALY_HH and ANOMALY_START <= ts[:10] <= ANOMALY_END:
            hp = round(min(hp_cap if hp_cap > 0 else hp, hp * ANOMALY_MULT), 3)

        house = r["house_load_kw"]
        ev = r["ev_charging_kw"]
        pv = r["pv_production_kw"]
        cons = round(house + hp + ev, 3)

        charge, discharge, imp, exp, soc = dispatch_step(pv, cons, soc, cap, pmax)

        # balance check: pv + imp + discharge == cons + exp + charge
        err = abs((pv + imp + discharge) - (cons + exp + charge))
        max_balance_err = max(max_balance_err, err)

        out.append({
            "timestamp": ts,
            "outdoor_temp_c": temp,
            "pv_production_kw": round(pv, 3),
            "house_load_kw": round(house, 3),
            "heatpump_kw": hp,
            "ev_charging_kw": round(ev, 3),
            "total_consumption_kw": cons,
            "battery_charge_kw": round(charge, 3),
            "battery_discharge_kw": round(discharge, 3),
            "battery_soc_kwh": round(soc, 3),
            "battery_soc_pct": round((soc / cap * 100) if cap > 0 else 0.0, 1),
            "grid_import_kw": round(imp, 3),
            "grid_export_kw": round(exp, 3),
            "price_eur_per_kwh": r["price_eur_per_kwh"],
        })

    json.dump({"household_id": hid, "resolution_minutes": 15, "year": 2025 + YEAR_SHIFT,
               "records": out},
              open(os.path.join(OUT, hh["timeseries_file"]), "w"))
    return out, max_balance_err


def recompute_bills(hid, recs, tariff):
    """Aggregate the re-simulated timeseries into monthly bills."""
    feed_in = tariff["feed_in_eur_per_kwh"]
    base_fee = tariff["base_fee_eur_per_month"]
    months = {}
    for r in recs:
        m = r["timestamp"][:7]
        b = months.setdefault(m, dict(cons=0, pv=0, imp=0, exp=0, cost=0))
        b["cons"] += r["total_consumption_kw"] * DT
        b["pv"] += r["pv_production_kw"] * DT
        b["imp"] += r["grid_import_kw"] * DT
        b["exp"] += r["grid_export_kw"] * DT
        b["cost"] += r["grid_import_kw"] * DT * r["price_eur_per_kwh"]
    bills = []
    for m in sorted(months):
        b = months[m]
        credit = b["exp"] * feed_in
        total = b["cost"] + base_fee - credit
        ss = (b["cons"] - b["imp"]) / b["cons"] * 100 if b["cons"] > 0 else 0
        bills.append({
            "household_id": hid, "month": m,
            "consumption_kwh": round(b["cons"], 1), "pv_production_kwh": round(b["pv"], 1),
            "grid_import_kwh": round(b["imp"], 1), "grid_export_kwh": round(b["exp"], 1),
            "energy_cost_eur": round(b["cost"], 2), "base_fee_eur": round(base_fee, 2),
            "feed_in_credit_eur": round(credit, 2), "total_bill_eur": round(total, 2),
            "self_sufficiency_pct": round(ss, 1),
        })
    return bills


def cheapest_hour(recs):
    """Hour-of-day with the lowest average price (for the nudge insight)."""
    by_hour = {}
    for r in recs:
        h = int(r["timestamp"][11:13])
        by_hour.setdefault(h, []).append(r["price_eur_per_kwh"])
    avg = {h: sum(v) / len(v) for h, v in by_hour.items()}
    h = min(avg, key=avg.get)
    return h, avg[h]


def main():
    os.makedirs(OUT, exist_ok=True)
    households = json.load(open(os.path.join(RAW, "households.json")))
    contracts = json.load(open(os.path.join(RAW, "contracts.json")))
    tariffs = {t["tariff_id"]: t for t in json.load(open(os.path.join(RAW, "tariffs.json")))}
    contracts_by_id = {c["household_id"]: c for c in contracts}
    forecast = load_forecast_15min()

    # passthrough reference files (copy as-is)
    json.dump(households, open(os.path.join(OUT, "households.json"), "w"), indent=2)
    json.dump(list(tariffs.values()), open(os.path.join(OUT, "tariffs.json"), "w"), indent=2)

    all_recs = {}
    print(f"{'home':9} {'max balance err (kW)':>22}")
    for hh in households:
        recs, err = transform_household(hh, contracts_by_id, forecast)
        all_recs[hh["household_id"]] = recs
        print(f"{hh['household_id']:9} {err:22.2e}")

    # monthly bills (recomputed)
    bills = []
    for hh in households:
        t = tariffs[hh["tariff_id"]]
        bills += recompute_bills(hh["household_id"], all_recs[hh["household_id"]], t)
    json.dump(bills, open(os.path.join(OUT, "monthly_bills.json"), "w"), indent=2)

    # dynamic prices: year-shift
    dp = json.load(open(os.path.join(RAW, "dynamic_prices.json")))
    dp["year"] = 2025 + YEAR_SHIFT
    for p in dp["prices"]:
        p["timestamp"] = shift_year(p["timestamp"])
    json.dump(dp, open(os.path.join(OUT, "dynamic_prices.json"), "w"))

    # contracts: year-shift dates + the hardcoded dates inside contract_terms_text
    for c in contracts:
        for k in ("contract_start", "contract_end"):
            c[k] = shift_year(c[k] + "T00:00:00")[:10]
        c["contract_terms_text"] = re.sub(
            r"\b(2024|2025|2026)-(\d{2})-(\d{2})\b",
            lambda m: f"{int(m.group(1)) + YEAR_SHIFT}-{m.group(2)}-{m.group(3)}",
            c["contract_terms_text"])
    json.dump(contracts, open(os.path.join(OUT, "contracts.json"), "w"), indent=2)

    # insight_events: realign anomaly to the cold week, recompute cheapest-window + top bill
    events = json.load(open(os.path.join(RAW, "insight_events.json")))
    bills_by_hh = {}
    for b in bills:
        bills_by_hh.setdefault(b["household_id"], []).append(b)
    new_events = []
    for e in events:
        hid = e["household_id"]
        e = dict(e)
        if e["type"] == "anomaly":
            if hid == ANOMALY_HH:
                e["period"] = f"{ANOMALY_START}..{ANOMALY_END}"
            else:
                e["period"] = re.sub(r"2025", "2026", e["period"])
                continue  # only keep the hero anomaly as a real injected one
        elif e["type"] == "nudge":
            h, price = cheapest_hour(all_recs[hid])
            e["title"] = f"Cheapest power is around {h:02d}:00"
            e["detail"] = (f"Over the year the lowest average price was at {h:02d}:00 "
                           f"(~EUR {price:.3f}/kWh). Shift flexible loads (EV, dishwasher, "
                           f"laundry) into this window.")
        elif e["type"] == "insight":
            hb = bills_by_hh.get(hid, [])
            if hb:
                top = max(hb, key=lambda b: b["total_bill_eur"])
                low = min(hb, key=lambda b: b["total_bill_eur"])
                e["period"] = top["month"]
                e["title"] = f"Highest bill in {top['month']}"
                e["detail"] = (f"{top['month']} cost EUR {top['total_bill_eur']:.2f} vs your low "
                               f"of EUR {low['total_bill_eur']:.2f} in {low['month']}, driven by "
                               f"heating demand and lower solar.")
        new_events.append(e)
    json.dump(new_events, open(os.path.join(OUT, "insight_events.json"), "w"), indent=2)

    print("\nWrote demo dataset to ./data/")


if __name__ == "__main__":
    main()
