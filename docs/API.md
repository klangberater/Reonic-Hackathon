# Lumen API reference

REST/JSON API for the Lumen energy assistant. Implemented in `backend/src/server.ts`
(Express). Endpoints map 1:1 to the app's product surfaces.

- **Base URL (production):** `https://getfletcher.ai/api` (nginx strips `/api/` → backend routes have no prefix)
- **Base URL (local):** `http://127.0.0.1:8090`
- **Content type:** `application/json`
- **Auth:** none, except the LLM/voice endpoints (`POST /chat`, `POST /transcribe`,
  `POST /plan_text`) when `CHAT_TOKEN` is configured (header `x-lumen-token`).

> **JSON casing.** Read models (`/now`, `/household`, `/devices`, `/insights`) emit
> **snake_case**; the planner/money/contract endpoints (`/money`, `/contract`, `/optimize_load`,
> `/plan_day`) emit **camelCase** (raw TypeScript object keys). The iOS client decodes with
> `convertFromSnakeCase`, which normalizes both. Shapes below show the actual wire keys.

## Common query parameters

| Param | Applies to | Default | Meaning |
|-------|-----------|---------|---------|
| `household` | all | `HH-1001` | `HH-1001`…`HH-1004`. `HH-1001` (Familie Becker, Munich) is the hero home. |
| `clock` | all | `summer` | `summer` = **live wall clock** (Europe/Berlin, snapped to 15 min, pinned to data year 2026); `summerday` = fixed `2026-06-20T11:00` (solar-soiling demo; "Sunny demo" in the app); `winter` = fixed `2026-01-15T08:00` (heat-pump-anomaly demo). Any unknown value falls back to live. |
| `at` | all | — | ISO timestamp override (e.g. `2026-06-20T13:00:00`); bypasses `clock`. For scripted demos/tests. |

On `GET`, params go in the query string; on `POST`, they may also be in the JSON body.

---

## Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/health` | Liveness. |
| GET | `/now` (alias `/state`) | The glance snapshot. |
| GET | `/household` | Asset profile + tariff. |
| GET | `/money` | Month-end bill / earnings forecast. |
| GET | `/contract` | Tariff, term dates, notice deadline, renewal + full terms text. |
| GET | `/devices` | Flexible devices + scheduled status. |
| GET | `/optimize_load` | Best window for one device (+ ribbon, per-hour slots, rationale). |
| POST | `/commit_load` | Add a load to the ledger. |
| GET | `/commitments` | List committed loads. |
| POST | `/reset` | Clear a household's ledger. |
| GET | `/insights` | Health + anomalies/nudges (heat-pump & solar). |
| POST | `/plan_day` | Schedule several tasks at once (the "Plan my day" engine). |
| POST | `/chat` | Grounded natural-language assistant. |
| POST | `/transcribe` | Voice clip (base64) → text (ElevenLabs STT). |
| POST | `/plan_text` | Sentence → tasks → plan → spoken summary (voice / text planning). |

---

### GET `/health`

```json
{ "status": "ok", "households": 4 }
```

---

### GET `/now`  (alias `/state`)

The glance snapshot. Returns `404` with `{ "error": ... }` if `at` has no record.

```jsonc
{
  "household_id": "HH-1001",
  "household_name": "Familie Becker",
  "at": "2026-06-20T18:30:00",
  "outdoor_temp_c": 29.4,
  "solar_kw": 1.91,             // = pv_production_kw
  "consumption_kw": 1.13,
  "breakdown_kw": { "house": 0.7, "heatpump": 0.0, "ev": 0.0 },
  "battery": { "soc_pct": 100, "flow_kw": 0.0, "state": "idle" },   // state: charging|discharging|idle
  "grid": { "flow_kw": 0.78, "direction": "exporting" },            // flow_kw>0 export, <0 import
  "price_eur_per_kwh": 0.39,
  "net_kw": 0.78,              // pv − consumption
  "status": "exporting_surplus" // exporting_surplus | drawing_grid | self_powered
}
```

---

### GET `/household`

```jsonc
{
  "household_id": "HH-1001", "name": "Familie Becker", "city": "Munich", "residents": 4,
  "pv_kwp": 9.8, "battery_kwh": 10, "battery_power_kw": 5,
  "heat_pump": true, "ev_charger": true, "ev_battery_kwh": 60,
  "tariff": {
    "tariff_id": "dynamic", "name": "Enpal FlexStrom Dynamic", "type": "dynamic_hourly",
    "spot_adder_eur_per_kwh": 0.119, "base_fee_eur_per_month": 12.9, "feed_in_eur_per_kwh": 0.081
  }
}
```

---

### GET `/money`

Month-to-date and projected end-of-month. **When `earning` is `true` the home is net-positive
and `projectedTotalEur` is a credit, not a cost.**

```jsonc
{
  "month": "2026-01", "costToDateEur": 320.35, "projectedTotalEur": 692,
  "earnedFromSolarEur": 0, "daysElapsed": 14, "daysInMonth": 31, "earning": false
}
```

In summer the hero home is net-positive (e.g. `projectedTotalEur` negative, `earning: true`).

---

### GET `/contract`

Parsed tariff + term intelligence (for "is this still a good deal?" and contract Q&A). Dates
are computed against the resolved `clock`. `inNoticeWindow` is `true` once within the notice
period before the term ends.

```jsonc
{
  "provider": "Enpal", "customerName": "Familie Becker",
  "tariffId": "dynamic", "tariffName": "Enpal FlexStrom Dynamic", "tariffType": "dynamic_hourly",
  "pricingModel": "dynamic_hourly", "baseFeeEurPerMonth": 12.9, "feedInEurPerKwh": 0.081,
  "spotAdderEurPerKwh": 0.119,
  "contractStart": "2025-03-19", "contractEnd": "2027-03-19",
  "minimumTermMonths": 24, "noticePeriodWeeks": 6, "autoRenewMonths": 12,
  "noticeByDate": "2027-02-05", "daysUntilEnd": 271, "daysUntilNoticeDeadline": 229,
  "inNoticeWindow": false,
  "termsText": "This agreement between Enpal B.V. and Familie Becker commences on 2025-03-19 …"
}
```

---

### GET `/devices`

The flexible-device library plus current schedule (from the ledger). `scheduled` is `null`
when idle.

```jsonc
[
  {
    "id": "ev", "name": "Car", "icon": "car",
    "energy_kwh": 18, "power_kw": 11, "controllable": true,
    "status": "scheduled",                                   // idle | scheduled
    "scheduled": { "start": "2026-06-20T17:00:00", "window": "17:00–18:45", "source": "free" }
  },
  { "id": "dishwasher", "name": "Dishwasher", "icon": "bowl", "energy_kwh": 1.2, "power_kw": 0.6,
    "controllable": false, "status": "idle", "scheduled": null }
]
```

Device ids: `ev`, `dishwasher`, `washing_machine`, `dryer`, plus `hot_water` and
`heating_boost` for homes with a heat pump. `source` ∈ `free | partial | paid`.

---

### GET `/optimize_load`

The greenest window to run **one** flexible load, classifying energy by **source** (free solar
→ battery → paid grid), routing around already-committed loads. One call powers three UI
surfaces: the recommendation, the 24-h ribbon, and the interactive per-hour picker.

**Query:** `device` (required), `deadline` (optional ISO, run must finish by it), plus the
common params.

```jsonc
{
  "device": "dishwasher", "deviceName": "Dishwasher", "controllable": false,
  "loadKwh": 1.2, "durationSlots": 8, "durationHours": 2,
  "start": "2026-01-15T13:00:00", "end": "2026-01-15T15:00:00", "window": "13:00–15:00",
  "source": "partial", "ownSharePct": 10, "gridCostEur": 0.42,
  "breakdownKwh": { "free": 0, "battery": 0.12, "grid": 1.08 },
  "ribbon": [ { "hour": "00:00", "source": "paid" }, … ],      // 24 cells, colour by source
  "slots":  [ { "hour": 0, "start": "...", "window": "00:00–02:00",
                "source": "paid", "ownSharePct": 0, "gridCostEur": 0.51, "feasible": true }, … ],
  "rationale": "Around 13:00–15:00, 10% comes from your own solar and battery; the rest is cheap grid (about €0.42)."
}
```

---

### POST `/commit_load`

Add a load to the in-memory ledger so subsequent plans route around it.

**Body:** `{ household?, clock?, device, start?, deadline?, at? }`. If `start` is omitted, the
backend optimizes and commits the best window.

```jsonc
// response
{ "committed": true, "device": "dishwasher", "start": "2026-01-15T12:00:00",
  "window": "12:00–14:00", "commitments": 1 }
```

### GET `/commitments`

```jsonc
[ { "householdId": "HH-1001", "device": "ev", "deviceName": "Car",
    "startISO": "2026-06-20T17:00:00", "startIdx": 16340, "durationSlots": 7,
    "powerKw": 11, "source": "free" } ]
```

### POST `/reset`

Clear a household's ledger (used between demo runs). Body `{ household? }` → `{ "ok": true }`.

---

### GET `/insights`

Live health + proactive cards. Anomalies are computed and weather-normalised (`anomaly.ts`) —
a **heat-pump** over-consumption (winter) or a **solar-soiling** under-production (summer);
the nudge (cheapest hour) and highest-bill note are live aggregations. `health` is `alert`
only when an active high-severity anomaly exists. Anomaly events carry a `subject`
(`"heatpump"` | `"solar"`) that seeds the app's "ask why" chat.

```jsonc
{
  "health": "alert",                       // ok | alert
  "events": [
    {
      "type": "anomaly",                   // anomaly | nudge | insight
      "severity": "high",                  // high | info
      "subject": "heatpump",               // heatpump | solar  (anomalies only)
      "period": "2026-01-12..2026-01-14",
      "title": "Heat pump using ~64% more than usual",
      "detail": "Heat-pump electricity is ~64% above what these temperatures normally need (2.2 kW vs ~1.4 kW), sustained 3 days.",
      "suggested_action": "Check heat pump settings / book a service inspection.",
      "active": true
    }
  ]
}
```

The summer solar-soiling anomaly (`clock=summerday`) looks the same with
`subject: "solar"`, e.g. *"Solar output ~55% below normal"*.

---

### POST `/plan_day`

Schedule several tasks at once — the engine behind "Plan my day". Computes **and commits** a
coordinated schedule (each task routes around the others via the ledger), returns the day's
solar curve and aggregate savings. Idempotent: re-plan / mode-toggle / nudge just call it again.

**Body:**
```jsonc
{
  "household": "HH-1001", "clock": "summer",
  "mode": "cheapest",                       // cheapest | greenest | soonest
  "tasks": [
    { "device": "ev", "deadline": "2026-06-21T07:00:00", "target": 80, "start": null },
    { "device": "dishwasher", "deadline": "2026-06-20T20:00:00" }
  ]
}
```
Per-task fields: `device` (required), `deadline` (ISO), `target` (EV charge %, 20–100), `start`
(ISO; pins a nudged task while the rest flow around it).

**Response:**
```jsonc
{
  "mode": "cheapest",
  "solarSharePct": 87, "savedEur": 10.95, "savedCo2Kg": 12.5,
  "curve": [ { "hour": 6, "solarKw": 0.4 }, … { "hour": 23, "solarKw": 0.0 } ],   // 18 points, 06–23
  "tasks": [
    { "device": "dishwasher", "name": "Dishwasher", "icon": "bowl",
      "start": "2026-06-20T13:00:00", "startHour": 13, "window": "13:00–15:00",
      "durationHours": 2, "source": "free", "ownSource": "solar",
      "ownSharePct": 100, "gridCostEur": 0, "controllable": false }
  ]
}
```
`source` is the cost story (`free | partial | paid`); `ownSource` is where the home's *own*
energy in that window comes from (`solar | battery | mixed | grid`). `savedEur` / `savedCo2Kg`
are vs. a "run it last-minute, finishing at the deadline" baseline.
Errors: `400 {error:"tasks required"}` (empty tasks), `400 {error:"bad mode"}`.

---

### POST `/chat`

Grounded assistant. Runs an OpenAI function-calling loop (`gpt-4o`) over the planner tools, so
every figure is computed, not generated. Requires `OPENAI_API_KEY` server-side (else `503`).

**Body:** `{ household?, clock?, message, history? }` where `history` is
`[{ role: "user"|"assistant", content }]`.
**Headers:** `x-lumen-token` if `CHAT_TOKEN` is configured.

```jsonc
// response
{ "reply": "Run the dishwasher around 1 pm — your panels cover it for free.",
  "toolsUsed": ["optimize_load"] }
```

Available tools the model may call: `get_now`, `get_money`, `get_household`, `get_contract`,
`get_devices`, `get_insights`, `list_commitments`, `optimize_load`, `explain_anomaly`,
`explain_solar_anomaly`. See
[ARCHITECTURE.md → Grounded assistant](ARCHITECTURE.md#grounded-assistant-openaichattts).

---

### POST `/transcribe`

Speech-to-text for the voice planner. Send a base64-encoded audio clip; get the transcript
back. Requires `ELEVENLABS_API_KEY` server-side (else `503`). Gated by `x-lumen-token` if
`CHAT_TOKEN` is set.

**Body:** `{ household?, audioBase64, mime? }` — `mime` defaults to `audio/m4a`.

```jsonc
// response
{ "text": "charge the car by 7am and run the dishwasher this afternoon" }
```

---

### POST `/plan_text`

The full voice/text planning pipeline: a sentence → structured tasks (GPT-4o) → `plan_day` →
a spoken one-line summary (ElevenLabs TTS, mp3 base64). Powers the hold-to-talk loop and the
typed fallback. Needs `OPENAI_API_KEY` (parsing) and `ELEVENLABS_API_KEY` (speech).

**Body:** `{ household?, clock?, at?, mode?, text }` — `mode` ∈ `cheapest | greenest | soonest`
(default `cheapest`).

```jsonc
// response
{
  "tasks": [ { "device": "ev", "deadline": "2026-06-21T07:00:00", "target": 80 }, … ],
  "notes": "…optional parser notes…",
  "plan":  { /* a full /plan_day result: curve, tasks, solarSharePct, savedEur, savedCo2Kg */ },
  "spokenLine": "All done on sunshine — €0.40 instead of €4.10, 92% on your own power.",
  "speechBase64": "<mp3 bytes, base64>"
}
```

Errors: `400 {error:"text required"}`; `422 {error:"I couldn't spot anything to schedule…"}`
when no device is recognised in the sentence; `503` if a required key is missing.

---

## cURL quick reference

```bash
api=https://getfletcher.ai/api            # or http://127.0.0.1:8090

curl -s "$api/health"
curl -s "$api/now?household=HH-1001&clock=summer"
curl -s "$api/contract?household=HH-1001"
curl -s "$api/insights?household=HH-1001&clock=summerday"     # solar-soiling anomaly
curl -s "$api/optimize_load?household=HH-1001&device=ev&clock=winter"

curl -s -X POST "$api/plan_day" -H 'content-type: application/json' -d '{
  "household":"HH-1001","clock":"summer","mode":"cheapest",
  "tasks":[{"device":"ev","deadline":"2026-06-21T07:00:00","target":80},
           {"device":"dishwasher","deadline":"2026-06-20T20:00:00"}]}'

# Plan from natural language (typed fallback for the voice loop)
curl -s -X POST "$api/plan_text" -H 'content-type: application/json' -d '{
  "household":"HH-1001","clock":"summerday",
  "text":"charge the car by 7am and run the dishwasher this afternoon"}'

curl -s -X POST "$api/chat" -H 'content-type: application/json' -d '{
  "household":"HH-1001","clock":"winter","message":"Why is my heat-pump bill so high?"}'

curl -s -X POST "$api/reset" -d '{"household":"HH-1001"}' -H 'content-type: application/json'
```
