# Plan My Day — Design

**Date:** 2026-06-20
**Status:** Approved, ready for implementation plan

## Summary

A second start screen, **"Plan my day"**, reachable by swiping horizontally from the
existing Home screen. The user picks energy-heavy tasks, sets a "done by" time for each,
and gets a schedule that runs them on as much solar as possible. The plan commits to the
same household ledger the Home screen reads, so scheduled tasks appear on both screens.

The screen has two states:
- **State 1 — Pick tasks:** a grid of task cards (multi-select), each with a "Done by"
  time and (for the car) a charge-target slider. Primary button: "Make my plan".
- **State 2 — The plan:** a summary chip, a Cheapest/Greenest/Soonest mode toggle, a hero
  timeline (solar curve + task blocks), a plain ordered-list fallback, tap-to-nudge, and
  a Re-plan button.

## Decisions (locked)

1. **Backend:** one new `/plan_day` endpoint that computes *and* commits the whole plan.
2. **Appliances:** add Dryer, Hot water boost, Heating boost to the device library so all
   six spec cards are real.
3. **Modes:** all three (Cheapest / Greenest / Soonest) are real, parametrizing the planner
   objective.
4. **Ledger:** "Make my plan" writes to the shared household ledger; Home reflects it.
5. **Nudge:** smart-assistant behavior — nudging a block pins that task and re-plans the
   rest around it.

---

## 1. Navigation (horizontal swipe)

`LumenApp` currently renders `HomeView()` directly. Introduce a `RootPager` view that owns
the shared `DemoClock` and pages between the two screens:

```swift
struct RootPager: View {
    @State private var page = 0
    @StateObject private var clockStore = ClockStore()   // holds the shared DemoClock
    var body: some View {
        TabView(selection: $page) {
            HomeView(clock: clockStore).tag(0)
            PlanDayView(clock: clockStore).tag(1)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea(.keyboard)
    }
}
```

- `indexDisplayMode: .never` so page dots don't collide with Home's bottom "Ask anything…"
  bar. Each screen carries a small 2-dot affordance in its header for swipe discoverability
  (filled dot = current screen).
- **Shared clock:** the `DemoClock` is lifted out of `HomeViewModel` into a small shared
  `ClockStore` (`ObservableObject`) injected into both screens, so both read the same
  time-anchored data and the same ledger. `HomeViewModel.setClock` semantics (reset ledger +
  reload on change) move to `ClockStore`.
- **Refresh on return:** when the user swipes back to Home after planning, Home re-pulls
  `/devices` via an `.onAppear` refresh so newly scheduled tasks show as "scheduled" there.
  (Guard against redundant reloads: only refetch devices, not the full snapshot.)

## 2. Backend

### 2.1 New devices (`backend/src/devices.ts`)

Extend `devicesFor` with three appliances (heat-based ones gated on `household.heat_pump`):

| id              | name             | icon       | energy kWh | duration | controllable |
|-----------------|------------------|------------|-----------:|---------:|--------------|
| `dryer`         | Dryer            | `dryer`    | 2.5        | 4 (1.0h) | false        |
| `hot_water`     | Hot water boost  | `shower`   | 3.0        | 4 (1.0h) | true (HP)    |
| `heating_boost` | Heating boost    | `flame`    | 4.0        | 4 (1.0h) | true (HP)    |

Car (`ev`) charge target → energy: assume car at 20% now, charging to `target`%:
`energyKwh = ev_battery_kwh × (target − 20) / 100` (floored at 0, default target 80).
`durationSlots = ceil(energyKwh / powerKw / 0.25)`. The EV device is constructed per-request
in `/plan_day` from the task's `target`, not from the static library.

iOS `DeviceRow`/`DeviceSheetView` symbol maps gain: `dryer → dryer.fill`,
`shower → shower.fill`, `flame → flame.fill`. Tints: dryer `Theme.grid`, hot water
`Theme.amber`, heating `Theme.red`.

### 2.2 Mode-aware planner (`backend/src/optimizeLoad.ts`)

Add an `objective` parameter to `optimizeLoad(householdId, device, nowISO, deadlineISO?, objective = "cheapest")`.
The window search keeps `evalWindow` unchanged; only the selection rule changes:

- **cheapest** — pick min `cost`; tie-break earliest start. (Current behavior.)
- **greenest** — pick max own energy `free + battery` (equivalently min grid kWh); tie-break
  min `cost`, then earliest.
- **soonest** — pick the earliest feasible start (`s == nowIdx` if feasible), regardless of
  source; tie-break min cost.

`slots`, `ribbon`, `rationale` stay as-is (driven by the chosen window).

### 2.3 `POST /plan_day` (`backend/src/server.ts`, new `planDay.ts`)

Request body:
```jsonc
{
  "household": "HH-1001",
  "clock": "summer",
  "mode": "cheapest",              // cheapest | greenest | soonest
  "tasks": [
    { "device": "ev",        "deadline": "2026-06-21T07:00:00", "target": 80, "start": null },
    { "device": "dishwasher","deadline": "2026-06-20T20:00:00",               "start": null }
  ]
}
```

Algorithm (`planDay.ts`):
1. Clear existing commitments for the requested devices only (so re-plan replaces cleanly;
   leaves any unrelated Home-scheduled devices intact — but in practice the same ledger key).
   Implementation: remove commitments whose `device` is in the task set, then re-place.
2. Sort tasks by `deadline` ascending (earliest deadline placed first; pinned `start` tasks
   placed first so the rest route around them).
3. For each task:
   - Build the device (EV rebuilt from `target`).
   - If `start` is set → pin: commit at that start (source from a single `evalWindow`).
   - Else → `optimizeLoad(..., deadline, mode)` against the *current* ledger; commit the
     winning start. Each commit makes the next task route around it.
   - Record placement: `startHour`, `window`, `durationHours`, `source`, `ownSharePct`,
     `gridCostEur`, `breakdownKwh`, `controllable`, `name`, `icon`.
4. **Solar curve:** `pv_production_kw` for hours 06–23 of the now-day, from the timeseries
   (one sample per hour, on the hour).
5. **Aggregate metrics:**
   - `solarSharePct` = Σ own kWh ÷ Σ total kWh across tasks (own = free + battery).
   - Baseline = each task run **last-minute, finishing exactly at its deadline** (car
     charging overnight to be ready by 7am, appliance in the evening), evaluated in
     isolation. The smart plan pulls the load onto solar instead, and the gap is the saving.
     This keeps the headline €/CO₂ honest *and* non-zero even at the solar-noon demo anchor,
     where a "run it right now" baseline would already be optimal. `savedEur` = Σ baseline
     cost − Σ plan cost (floored at 0).
   - `savedCo2Kg` = (Σ baseline grid kWh − Σ plan grid kWh) × 0.40 (German grid factor,
     named constant `CO2_KG_PER_KWH`).

Response:
```jsonc
{
  "mode": "cheapest",
  "solarSharePct": 85,
  "savedEur": 1.40,
  "savedCo2Kg": 3.0,
  "curve": [ { "hour": 6, "solarKw": 0.4 }, … { "hour": 23, "solarKw": 0.0 } ],
  "tasks": [
    { "device": "dishwasher", "name": "Dishwasher", "icon": "bowl",
      "startHour": 11, "start": "2026-06-20T11:30:00", "window": "11:30–13:30",
      "durationHours": 2.0, "source": "free", "ownSharePct": 100,
      "gridCostEur": 0.0, "controllable": false }, …
  ]
}
```

`/commit_plan` is **not** a separate endpoint — `/plan_day` commits as it computes. Re-plan,
mode-toggle, and nudge all re-call `/plan_day`; `addCommitment` replaces per device, so this
is idempotent. The Home screen, reading the same ledger, shows the scheduled tasks after its
on-appear refresh.

## 3. iOS — `PlanDayView` + `PlanDayViewModel`

### 3.1 ViewModel

```swift
@MainActor final class PlanDayViewModel: ObservableObject {
    @Published var phase: Phase = .pick           // .pick | .plan
    @Published var selected: [String: TaskInput]  // deviceId → {deadline, target}
    @Published var mode: PlanMode = .cheapest
    @Published var plan: PlanResult?
    @Published var devices: [Device] = []         // from /devices (now 6)
    @Published var isLoading = false
    @Published var errorText: String?
    @Published var nudged: [String: String]       // deviceId → pinned start ISO
}
```

- `loadDevices()` on first appear (uses shared clock).
- `makePlan()` / `replan()` → POST `/plan_day` with selected tasks, mode, and any `nudged`
  starts; sets `plan`, moves to `.plan`.
- `setMode(_:)` → re-plan with new mode.
- `nudge(device:deltaHours:)` → adjust that device's pinned start within its deadline, set
  `nudged[device]`, re-plan (rest route around it).

### 3.2 State 1 — Pick tasks

- Header: "What do you want to do today?" + the 2-dot swipe affordance.
- `LazyVGrid` (2 columns) of cards from `devices`: icon + label, tap toggles selection,
  selected = `Theme.green` tint + filled background (`.cardSurface()` base).
- Below the grid, one expanding row per selected task:
  - **"Done by"** compact time picker. Defaults: car `07:00` next day; appliances `20:00`
    today; hot water / heating `19:00` today.
  - Car only: **charge-target** `Slider` 50–100%, default 80%, label "Charge to 80%".
- Primary button **"Make my plan"** (disabled when nothing selected) → `makePlan()`.

### 3.3 State 2 — The plan

- **Summary chip** (capsule, `Theme.greenSoft`): "{solarSharePct}% solar · saves
  €{savedEur} / {savedCo2Kg} kg CO₂ today".
- **Mode toggle:** segmented `Picker` (Cheapest / Greenest / Soonest) → `setMode`.
- **Hero timeline** — new `DayTimeline` view (SwiftUI `Canvas`):
  - x-axis 06:00–23:00 (17 h); hour gridlines at 06/12/18/23.
  - Background: solar `curve` as a filled area path (normalized to its max), soft green.
  - Task blocks: rounded capsules at `startHour`, width = `durationHours`, packed into lanes
    to avoid overlap, labeled with SF Symbol + name. Each block split-shaded:
    `ownSharePct` portion `Theme.green`, remainder `Theme.grid` grey.
  - Tap a block → selects it; inline earlier/later steppers (±1 h, clamped to deadline) call
    `nudge`, which pins it and re-plans the rest. Selected block gets an `ink` stroke.
- **Fallback ordered list:** "11:30 Dishwasher · 13:00 Charge car · 18:00 Hot water…",
  one line per task sorted by start.
- **Re-plan** button → `replan()` (clears `nudged`, recomputes from scratch in current mode).
- Secondary: "Edit tasks" → back to `.pick` keeping the selection.

### 3.4 Models (`Models.swift`)

```swift
struct PlanResult: Decodable, Sendable {
    let mode: String
    let solarSharePct: Double
    let savedEur: Double
    let savedCo2Kg: Double
    let curve: [CurvePoint]
    let tasks: [PlannedTask]
    struct CurvePoint: Decodable, Sendable, Identifiable { let hour: Int; let solarKw: Double; var id: Int { hour } }
    struct PlannedTask: Decodable, Sendable, Identifiable {
        let device, name, icon, start, window, source: String
        let startHour: Int; let durationHours, ownSharePct, gridCostEur: Double
        let controllable: Bool
        var id: String { device }
    }
}
enum PlanMode: String, CaseIterable, Identifiable { case cheapest, greenest, soonest; var id: String { rawValue } }
```

### 3.5 APIClient (`APIClient.swift`)

Add `planDay(tasks:mode:clock:) async throws -> PlanResult` posting to `/plan_day`
(JSON body via the existing `postJSON` helper, since the body has a nested array).

## 4. Files touched

**Backend**
- `backend/src/devices.ts` — add 3 devices; EV target→energy helper.
- `backend/src/optimizeLoad.ts` — add `objective` param + selection rules.
- `backend/src/planDay.ts` — **new** — orchestration, curve, savings.
- `backend/src/server.ts` — add `POST /plan_day`.

**iOS**
- `ios/Sources/LumenApp.swift` — render `RootPager`.
- `ios/Sources/RootPager.swift` — **new** — paged TabView + `ClockStore`.
- `ios/Sources/ClockStore.swift` — **new** — shared clock (extracted from HomeViewModel).
- `ios/Sources/HomeView.swift` / `HomeViewModel.swift` — accept injected clock; on-appear
  device refresh; symbol maps for new icons.
- `ios/Sources/PlanDayView.swift` — **new** — the screen (both states).
- `ios/Sources/PlanDayViewModel.swift` — **new**.
- `ios/Sources/DayTimeline.swift` — **new** — Canvas timeline.
- `ios/Sources/Models.swift` — `PlanResult`, `PlanMode`.
- `ios/Sources/APIClient.swift` — `planDay`.

## 5. Edge cases

- **No tasks selected** → "Make my plan" disabled.
- **Deadline before now** → backend clamps horizon; if a task can't fit before its deadline,
  it's placed at `now` and flagged `source: "paid"` (UI shows it grid-grey). Frontend keeps
  showing it; no hard error.
- **Heat pump absent** → hot water / heating cards not offered (devices list omits them).
- **Backend unreachable** → existing error-card pattern (`errorText`), Retry re-calls.
- **Nudge past deadline** → later stepper clamped so the task still finishes by its deadline.
- **Re-plan determinism** → same inputs + same clock ⇒ same plan (planner is deterministic).
- **Curve at night** → hours with ~0 solar render a flat baseline; blocks there read grey.

## 6. Testing

- **Backend unit (planDay):** with summer clock + {dishwasher 20:00, ev 07:00+1, target 80}
  → assert all tasks placed, EV energy = capacity×0.6, `solarSharePct` > 0, `savedEur` ≥ 0,
  curve length = 18, second task routes around the first (non-overlapping solar claim).
- **Mode differences:** assert `soonest` start ≤ `cheapest` start for a midday-deadline task;
  `greenest` own-share ≥ `cheapest` own-share.
- **Nudge:** pin EV start one hour later → assert EV start moves, appliance re-routes.
- **iOS:** manual — pick 3 tasks, make plan, toggle all three modes, nudge a block, re-plan,
  swipe back to Home and confirm the tasks show "scheduled".
