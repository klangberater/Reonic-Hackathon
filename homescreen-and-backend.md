# Home Screen — Concept & Backend Needs

A calm, assistant-voiced home screen: one plain-language status line, one money number, and
tappable device tiles that schedule loads onto your own solar. No charts, no jargon on the
surface. The detail and the math live one tap (or one question) away.

---

## 1. Home screen anatomy (top → bottom)

| Element | What it shows | Notes |
|---|---|---|
| **Status indicator** | tiny "All good" with a green dot | quiet by default; becomes a loud card when something's wrong (see states) |
| **Verdict line** | one plain sentence, assistant voice — *"You're running on free solar right now."* | this is the comprehension product; protect it |
| **Money** | one forward number — *"On track for €96 this month."* | a forecast, not a balance-to-date |
| **Device tiles** | *"What do you want to run?"* — car, dishwasher, washing machine, + add | each tile shows status; tapping opens the device sheet |
| **Ask bar** | persistent *"Ask anything…"* in the thumb zone | the assistant is always present, not a corner button |

Everything heavier (live flow, bill breakdown, full day timeline) is reached by tapping the
relevant element — the assistant lets us *not* pre-display it.

---

## 2. The core interaction: tap → best time → confirm → plan

1. **Tap a device tile** → a sheet opens with: the best (greenest) time, the run duration, the
   source (free / partial / paid), a slim source-ribbon showing where the slot lands in the day,
   and a one-line rationale.
2. **Confirm** → the load is added to a committed-loads ledger.
3. **The next device routes around it.** Because the planner is sequential, a confirmed load
   claims its solar/battery first, so the next device sees what's left and plans accordingly.
   Confirmed plans never silently move.

This is what turns the app from an *advisor* into a *planner* — the single most differentiating
piece versus every incumbent app.

---

## 3. The traffic light = energy SOURCE, not price

The ribbon (in the device sheet, not on the home screen) colors the day by where the energy
comes from, which is what a homeowner actually feels:

- **Green — free:** your solar, or your battery (stored solar), covers the whole load.
- **Yellow — partial:** some yours, some grid.
- **Red — paid:** all bought from the grid.

Source-first works on **both tariff types** — a fixed-tariff home has no hourly price to tier,
but still has a meaningful free/paid story. The battery counts as your own energy, so the green
window stretches past sunset.

---

## 4. States to design (not just happy path)

- **Health indicator:** green/quiet → on an anomaly (e.g. heat-pump fault) it becomes the loudest
  card on the screen. Same component, two volumes.
- **Device tile:** idle ("tap to plan") · scheduled ("1–4 pm · free") · running · done.
- **Source:** free / partial / paid (used on tiles, ribbon, sheet).
- **Control honesty:** the car is genuinely controllable (wallbox) → confirm = real automation.
  Appliances usually aren't → confirm = "set your delay-start / we'll remind you." Say which.

---

## 5. What the backend provides (the contract — one line each)

| # | Call | Returns |
|---|---|---|
| 1 | `GET household` | asset profile: PV, battery, heat pump, EV battery, tariff |
| 2 | `GET now` | the verdict inputs: live flow + battery SoC at the virtual "now" |
| 3 | `GET money` | projected month-end bill + earned-from-solar |
| 4 | `GET devices` | device list + profiles (appliance library + EV) |
| 5 | `optimize_load(device, deadline?)` | recommended window, source, own-share %, grid cost, **ribbon**, **rationale** |
| 6 | `commit_load` / `list_commitments` | the committed-loads ledger |
| 7 | `POST chat` | Claude grounded on calls 1–6 as tools |
| 8 | `GET insights` | anomalies & nudges → drives the health indicator + proactive cards |

**One call, three surfaces:** `optimize_load` already returns the tile's recommendation, the
ribbon, and the chat/sheet rationale — so tiles, ribbon, and assistant never disagree. The engine
for it is in `optimizeLoad.ts`.

---

## 6. Backend behaviors that matter (brief)

- **Virtual "now":** the data is historical 2025, so pick an anchor timestamp and treat it as
  "now" everywhere. Choose it so the demo's verdict and recommendations land well.
- **Committed-loads ledger:** in-memory is fine for the demo; greedy + sequential.
- **Source-first objective:** minimize grid cost → free windows win, then cheapest grid. Same rule
  covers dynamic and fixed tariffs.
- **No live hardware:** everything is read from the uploaded synthetic JSON.

---

## 7. Where each backend need gets its data

| Backend need | Source file(s) |
|---|---|
| Household / assets | `households.json`, `contracts.json` |
| Now snapshot, ribbon, optimize_load | `energy_timeseries_<id>.json` (+ `dynamic_prices.json`) |
| Money forecast | `monthly_bills.json` (+ month-to-date from timeseries) |
| Devices | seeded appliance library + EV from `contracts.json` (`ev_battery_kwh`) |
| Insights / health | `insight_events.json` |
| Contract / tariff Q&A | `contracts.json`, `tariffs.json` |

⚠️ Two gotchas from the data: the timeseries and prices files wrap their rows under `records` /
`prices` keys (not top-level arrays), and `outdoor_temp_c` is seasonally inverted — don't show it,
and don't derive weather-causation from it.

---

## 8. Out of scope (hackathon)

Auth, real persistence, real device control, onboarding flows, multi-home. Synthetic data and an
in-memory ledger are enough to demo the whole experience.
