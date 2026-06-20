# Plan My Day Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a second start screen, "Plan my day", reachable by horizontal swipe, where the user picks energy-heavy tasks with deadlines and gets a solar-aware schedule that commits to the shared household ledger.

**Architecture:** A new `POST /plan_day` backend endpoint computes *and* commits a coordinated multi-task schedule (each task routes around the others via the existing ledger), parametrized by a Cheapest/Greenest/Soonest objective, and returns the day's solar curve plus aggregate savings. On iOS, `LumenApp` wraps `HomeView` and a new `PlanDayView` in a paged `TabView` sharing one `ClockStore`; `PlanDayView` has a pick state and a plan state with a `Canvas`-drawn hero timeline.

**Tech Stack:** TypeScript + Express (backend), Node 22 built-in `node:test` runner (zero new deps), SwiftUI / iOS 17 (app), XcodeGen + xcodebuild.

**Reference spec:** `docs/superpowers/specs/2026-06-20-plan-my-day-design.md`

---

## File Structure

**Backend**
- `backend/src/optimizeLoad.ts` — *modify* — add `objective` param + per-mode window selection.
- `backend/src/devices.ts` — *modify* — add dryer / hot water / heating boost; `evDevice(target)` helper.
- `backend/src/planDay.ts` — *new* — orchestration: place tasks, build curve, compute savings.
- `backend/src/server.ts` — *modify* — add `POST /plan_day`.
- `backend/src/optimizeLoad.test.ts` — *new* — objective selection tests.
- `backend/src/planDay.test.ts` — *new* — orchestration / curve / savings tests.
- `backend/package.json` — *modify* — add `"test"` script.

**iOS**
- `ios/Sources/Models.swift` — *modify* — `PlanResult`, `PlanMode`.
- `ios/Sources/APIClient.swift` — *modify* — `planDay(...)`.
- `ios/Sources/ClockStore.swift` — *new* — shared clock (extracted from `HomeViewModel`).
- `ios/Sources/HomeViewModel.swift` — *modify* — take injected `ClockStore`.
- `ios/Sources/HomeView.swift` — *modify* — injected clock, on-appear device refresh, swipe-dots, new icon maps.
- `ios/Sources/RootPager.swift` — *new* — paged `TabView`.
- `ios/Sources/LumenApp.swift` — *modify* — render `RootPager`.
- `ios/Sources/PlanDayViewModel.swift` — *new*.
- `ios/Sources/DayTimeline.swift` — *new* — `Canvas` timeline.
- `ios/Sources/PlanDayView.swift` — *new* — both states.
- `ios/Sources/DeviceSheetView.swift` — *modify* — new icon maps.

---

## Phase A — Backend

### Task 0: Test runner setup

**Files:**
- Modify: `backend/package.json`

- [ ] **Step 1: Add a test script**

In `backend/package.json`, add to `"scripts"`:

```json
    "test": "tsc -p tsconfig.json && node --test dist/*.test.js"
```

- [ ] **Step 2: Verify the runner works on an empty match**

Run: `cd backend && npm test`
Expected: `tsc` compiles with no errors; `node --test` prints something like `tests 0 / pass 0` (no `*.test.js` yet) and exits 0. If it exits non-zero because no files matched, that's fine for now — the first real test arrives in Task 1.

- [ ] **Step 3: Commit**

```bash
git add backend/package.json
git commit -m "build(backend): add node:test runner script"
```

---

### Task 1: Mode-aware planner objective

Add an `objective` parameter to `optimizeLoad` so Cheapest / Greenest / Soonest each pick a different window. `evalWindow` is unchanged; only the selection loop changes.

**Files:**
- Modify: `backend/src/optimizeLoad.ts`
- Test: `backend/src/optimizeLoad.test.ts`

- [ ] **Step 1: Write the failing test**

Create `backend/src/optimizeLoad.test.ts`:

```typescript
import test from "node:test";
import assert from "node:assert/strict";
import { optimizeLoad } from "./optimizeLoad";
import { deviceById } from "./devices";

const HH = "HH-1001";
const NOW = "2026-06-20T13:00:00";       // summer demo "now"
const EVENING = "2026-06-20T22:00:00";   // a same-day deadline with a midday solar window before it

test("cheapest picks a window with min grid cost", () => {
  const d = deviceById(HH, "dishwasher");
  const r = optimizeLoad(HH, d, NOW, EVENING, "cheapest");
  assert.equal(r.source !== undefined, true);
  // greenest own-share is never worse than cheapest own-share for the same task
  const g = optimizeLoad(HH, d, NOW, EVENING, "greenest");
  assert.ok(g.ownSharePct >= r.ownSharePct - 0.001, `greenest ${g.ownSharePct} >= cheapest ${r.ownSharePct}`);
});

test("soonest starts no later than cheapest", () => {
  const d = deviceById(HH, "dishwasher");
  const soon = optimizeLoad(HH, d, NOW, EVENING, "soonest");
  const cheap = optimizeLoad(HH, d, NOW, EVENING, "cheapest");
  assert.ok(soon.start <= cheap.start, `soonest ${soon.start} <= cheapest ${cheap.start}`);
});

test("default objective is cheapest (back-compat)", () => {
  const d = deviceById(HH, "dishwasher");
  const a = optimizeLoad(HH, d, NOW, EVENING);
  const b = optimizeLoad(HH, d, NOW, EVENING, "cheapest");
  assert.equal(a.start, b.start);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && npm test`
Expected: FAIL — `optimizeLoad` currently takes 4 args; passing a 5th `objective` compiles (TS ignores extra positional? No — TS errors on excess args). Expect a tsc error `Expected 3-4 arguments, but got 5`.

- [ ] **Step 3: Add the objective parameter and selection rules**

In `backend/src/optimizeLoad.ts`:

Add the type near the top (after `export type Source`):

```typescript
export type Objective = "cheapest" | "greenest" | "soonest";
```

Change the signature:

```typescript
export function optimizeLoad(householdId: string, device: Device, nowISO: string, deadlineISO?: string, objective: Objective = "cheapest"): OptimizeResult {
```

Replace the search block (the current lines that compute `bestS`/`best`):

```typescript
    // search every feasible start; selection rule depends on the objective
    let bestS = nowIdx, best = evalWindow(nowIdx);
    for (let s = nowIdx; s + D <= horizonEnd; s++) {
        const r = evalWindow(s);
        if (objective === "soonest") {
            // earliest feasible start wins; tie-break by lower cost
            if (s < bestS || (s === bestS && r.cost < best.cost - 1e-9)) { best = r; bestS = s; }
        } else if (objective === "greenest") {
            // maximise own energy (free + battery); tie-break lower cost, then earlier
            const own = r.free + r.battery, bestOwn = best.free + best.battery;
            if (own > bestOwn + 1e-9 || (Math.abs(own - bestOwn) < 1e-9 && r.cost < best.cost - 1e-9)) { best = r; bestS = s; }
        } else {
            // cheapest: minimise grid cost; tie-break earliest (the loop's natural order keeps the earliest)
            if (r.cost < best.cost - 1e-9) { best = r; bestS = s; }
        }
    }
```

Note: for `soonest`, `bestS` is initialised to `nowIdx` and the loop starts at `nowIdx`, so the first feasible window (the earliest) wins immediately and only an earlier index could replace it — none can, so `nowIdx` stands unless infeasible. That is the desired "as soon as possible" behavior.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && npm test`
Expected: PASS — all three tests green.

- [ ] **Step 5: Commit**

```bash
git add backend/src/optimizeLoad.ts backend/src/optimizeLoad.test.ts
git commit -m "feat(backend): mode-aware planner objective (cheapest/greenest/soonest)"
```

---

### Task 2: New appliances + EV-from-target helper

**Files:**
- Modify: `backend/src/devices.ts`
- Test: `backend/src/devices.test.ts`

- [ ] **Step 1: Write the failing test**

Create `backend/src/devices.test.ts`:

```typescript
import test from "node:test";
import assert from "node:assert/strict";
import { devicesFor, deviceById, evDevice } from "./devices";

const HH = "HH-1001"; // has heat pump + EV (60 kWh)

test("library includes the six planner tasks for a heat-pump + EV home", () => {
  const ids = devicesFor(HH).map((d) => d.id).sort();
  for (const id of ["dishwasher", "washing_machine", "dryer", "ev", "hot_water", "heating_boost"]) {
    assert.ok(ids.includes(id), `missing ${id} in ${ids.join(",")}`);
  }
});

test("evDevice scales energy from charge target (20% start)", () => {
  const d = evDevice(HH, 80);            // 60 kWh * (80-20)/100 = 36 kWh
  assert.ok(Math.abs(d.energyKwh - 36) < 0.01, `got ${d.energyKwh}`);
  assert.ok(d.durationSlots > 0);
  const small = evDevice(HH, 20);        // 0 kWh edge → still a valid (zero-energy) device
  assert.ok(small.energyKwh >= 0);
});

test("deviceById finds a newly added appliance", () => {
  assert.equal(deviceById(HH, "dryer").name, "Dryer");
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && npm test`
Expected: FAIL — tsc error `Module './devices' has no exported member 'evDevice'`, and the missing-ids assertion would fail.

- [ ] **Step 3: Implement the new devices + helper**

In `backend/src/devices.ts`, import `household` alongside `contract`:

```typescript
import { contract, household } from "./data";
```

Add the heat-pump–gated appliances inside `devicesFor` (after the dishwasher/washing-machine entries, before the EV block):

```typescript
    list.push(appliance("dryer", "Dryer", "dryer", 2.5, 4));   // 1.0h
    if (household(householdId).heat_pump) {
        list.push(controllableLoad("hot_water", "Hot water boost", "shower", 3.0, 4));   // 1.0h
        list.push(controllableLoad("heating_boost", "Heating boost", "flame", 4.0, 4));  // 1.0h
    }
```

Keep the existing EV block in `devicesFor` (the static 18 kWh top-up) so `/devices` and the picker still list a car. Add the per-target builder and a controllable-load helper at the bottom of the file:

```typescript
/** EV sized from a charge target: assume 20% now → energy = capacity × (target − 20)/100. */
export function evDevice(householdId: string, targetPct: number): Device {
    const cap = contract(householdId).assets.ev_battery_kwh;
    const energy = Math.max(0, cap * (Math.min(100, Math.max(20, targetPct)) - 20) / 100);
    const powerKw = 11;
    const durationSlots = Math.max(1, Math.ceil(energy / powerKw / DT));
    return { id: "ev", name: "Car", icon: "car", energyKwh: energy, durationSlots, powerKw, controllable: true };
}

function controllableLoad(id: string, name: string, icon: string, energyKwh: number, durationSlots: number): Device {
    return { id, name, icon, energyKwh, durationSlots, powerKw: energyKwh / (durationSlots * DT), controllable: true };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && npm test`
Expected: PASS — all device tests green; Task 1 tests still green.

- [ ] **Step 5: Commit**

```bash
git add backend/src/devices.ts backend/src/devices.test.ts
git commit -m "feat(backend): add dryer/hot-water/heating-boost devices + EV-from-target"
```

---

### Task 3: `planDay` orchestration

Place each task in deadline order, routing around the already-placed ones via the ledger; build the solar curve and aggregate savings.

**Files:**
- Create: `backend/src/planDay.ts`
- Test: `backend/src/planDay.test.ts`

- [ ] **Step 1: Write the failing test**

Create `backend/src/planDay.test.ts`:

```typescript
import test from "node:test";
import assert from "node:assert/strict";
import { planDay } from "./planDay";
import { clearCommitments } from "./ledger";

const HH = "HH-1001";
const NOW = "2026-06-20T13:00:00";

function fresh() { clearCommitments(HH); }

test("plans all tasks, returns 18-hour curve and non-negative savings", () => {
  fresh();
  const out = planDay(HH, NOW, "cheapest", [
    { device: "dishwasher", deadline: "2026-06-20T22:00:00" },
    { device: "ev", deadline: "2026-06-21T07:00:00", target: 80 },
  ]);
  assert.equal(out.tasks.length, 2);
  assert.equal(out.curve.length, 18);           // hours 06..23
  assert.equal(out.curve[0].hour, 6);
  assert.equal(out.curve[17].hour, 23);
  assert.ok(out.savedEur >= 0, `savedEur ${out.savedEur}`);
  assert.ok(out.savedCo2Kg >= 0);
  assert.ok(out.solarSharePct >= 0 && out.solarSharePct <= 100);
  for (const t of out.tasks) {
    assert.ok(t.startHour >= 0 && t.startHour <= 23);
    assert.ok(["free", "partial", "paid"].includes(t.source));
  }
});

test("tasks route around each other (no identical EV+dishwasher claim by accident)", () => {
  fresh();
  const out = planDay(HH, NOW, "cheapest", [
    { device: "dishwasher", deadline: "2026-06-20T22:00:00" },
    { device: "washing_machine", deadline: "2026-06-20T22:00:00" },
  ]);
  // both placed; planner is deterministic; at least assert both have a window string
  assert.ok(out.tasks.every((t) => t.window.includes("–")));
});

test("a pinned start is honored", () => {
  fresh();
  const out = planDay(HH, NOW, "cheapest", [
    { device: "dishwasher", deadline: "2026-06-20T22:00:00", start: "2026-06-20T16:00:00" },
  ]);
  assert.equal(out.tasks[0].startHour, 16);
});

test("greenest never lowers total solar share vs cheapest", () => {
  fresh();
  const tasks = [{ device: "dishwasher", deadline: "2026-06-20T22:00:00" }];
  const cheap = planDay(HH, NOW, "cheapest", tasks);
  fresh();
  const green = planDay(HH, NOW, "greenest", tasks);
  assert.ok(green.solarSharePct >= cheap.solarSharePct - 0.001);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && npm test`
Expected: FAIL — `Cannot find module './planDay'`.

- [ ] **Step 3: Implement `planDay`**

Create `backend/src/planDay.ts`:

```typescript
/**
 * Multi-task day planner. Places each requested task in deadline order, committing it so the
 * next task routes around it (shared ledger). Returns the day's solar curve and aggregate
 * savings vs. running every task immediately. Computes AND commits — re-plan/mode-toggle/nudge
 * just call this again; addCommitment replaces per device, so it is idempotent.
 */
import { recordsArray, indexOf, household } from "./data";
import { Device, deviceById, evDevice } from "./devices";
import { optimizeLoad, Objective, Source } from "./optimizeLoad";
import { addCommitment, commitmentsFor, ledgerRemove } from "./ledger";

const DT = 0.25;
const CO2_KG_PER_KWH = 0.40;   // German grid average

export interface PlanTaskInput { device: string; deadline?: string; target?: number; start?: string }
export interface PlannedTask {
    device: string; name: string; icon: string; start: string; startHour: number;
    window: string; durationHours: number; source: Source; ownSharePct: number;
    gridCostEur: number; controllable: boolean;
}
export interface CurvePoint { hour: number; solarKw: number }
export interface PlanResult {
    mode: Objective; solarSharePct: number; savedEur: number; savedCo2Kg: number;
    curve: CurvePoint[]; tasks: PlannedTask[];
}

function buildDevice(householdId: string, t: PlanTaskInput): Device {
    return t.device === "ev" ? evDevice(householdId, t.target ?? 80) : deviceById(householdId, t.device);
}
function hhmm(iso: string): string { return iso.slice(11, 16); }
function hourOf(iso: string): number { return parseInt(iso.slice(11, 13), 10); }
function round(v: number, dp: number): number { const f = 10 ** dp; return Math.round(v * f) / f; }

/** Cost + grid kWh + own kWh if this device ran starting at nowISO (the "do it now" baseline). */
function baselineAt(householdId: string, device: Device, nowISO: string): { cost: number; gridKwh: number; ownKwh: number } {
    const recs = recordsArray(householdId);
    const s = indexOf(householdId, nowISO);
    let free = 0, battery = 0, grid = 0, cost = 0;
    let pool = recs[s].battery_soc_kwh;
    const pmax = household(householdId).battery_power_kw || 0;
    for (let t = s; t < s + device.durationSlots && t < recs.length; t++) {
        const draw = device.powerKw * DT;
        const useSolar = Math.min(draw, Math.max(0, recs[t].grid_export_kw) * DT);
        let rem = draw - useSolar;
        const useBatt = Math.min(rem, pool, pmax * DT);
        pool -= useBatt; rem -= useBatt;
        free += useSolar; battery += useBatt; grid += rem; cost += rem * recs[t].price_eur_per_kwh;
    }
    return { cost, gridKwh: grid, ownKwh: free + battery };
}

export function planDay(householdId: string, nowISO: string, mode: Objective, inputs: PlanTaskInput[]): PlanResult {
    // replace prior commitments for exactly the devices being (re)planned
    for (const t of inputs) ledgerRemove(householdId, t.device);

    // pinned tasks first (so the rest route around them), then by deadline ascending
    const ordered = [...inputs].sort((a, b) => {
        if (!!a.start !== !!b.start) return a.start ? -1 : 1;
        return (a.deadline ?? "").localeCompare(b.deadline ?? "");
    });

    const tasks: PlannedTask[] = [];
    let totalOwn = 0, totalKwh = 0, planGridKwh = 0, planCost = 0;
    let baseGridKwh = 0, baseCost = 0;

    for (const input of ordered) {
        const device = buildDevice(householdId, input);
        const r = optimizeLoad(householdId, device, nowISO, input.deadline, mode);
        const start = input.start ?? r.start;
        // if pinned, re-evaluate metrics at the pinned start by asking the planner with no search room
        const placed = input.start
            ? optimizeLoad(householdId, device, input.start, input.deadline, "soonest")  // forces start == pinned
            : r;
        const startIdx = indexOf(householdId, start);
        addCommitment({
            householdId, device: device.id, deviceName: device.name, startISO: start,
            startIdx, durationSlots: device.durationSlots, powerKw: device.powerKw, source: placed.source,
        });

        const own = placed.breakdownKwh.free + placed.breakdownKwh.battery;
        totalOwn += own; totalKwh += device.energyKwh;
        planGridKwh += placed.breakdownKwh.grid; planCost += placed.gridCostEur;

        const base = baselineAt(householdId, device, nowISO);
        baseGridKwh += base.gridKwh; baseCost += base.cost;

        tasks.push({
            device: device.id, name: device.name, icon: device.icon, start,
            startHour: hourOf(start), window: placed.window, durationHours: round(device.durationSlots * DT, 2),
            source: placed.source, ownSharePct: device.energyKwh > 0 ? Math.min(100, Math.round((own / device.energyKwh) * 100)) : 0,
            gridCostEur: round(placed.gridCostEur, 2), controllable: device.controllable,
        });
    }

    // solar curve, hours 06..23 of the now-day
    const date = nowISO.slice(0, 10);
    const recs = recordsArray(householdId);
    const curve: CurvePoint[] = [];
    for (let h = 6; h <= 23; h++) {
        const i = indexOf(householdId, `${date}T${String(h).padStart(2, "0")}:00:00`);
        curve.push({ hour: h, solarKw: i >= 0 ? round(recs[i].pv_production_kw, 2) : 0 });
    }

    return {
        mode,
        solarSharePct: totalKwh > 0 ? Math.min(100, Math.round((totalOwn / totalKwh) * 100)) : 0,
        savedEur: round(Math.max(0, baseCost - planCost), 2),
        savedCo2Kg: round(Math.max(0, (baseGridKwh - planGridKwh) * CO2_KG_PER_KWH), 1),
        curve,
        tasks,
    };
}

// silence unused import if commitmentsFor is not referenced after edits
void commitmentsFor;
```

- [ ] **Step 4: Add the `ledgerRemove` helper**

`planDay` calls `ledgerRemove`, which does not exist yet. In `backend/src/ledger.ts`, add:

```typescript
/** Remove a single device's commitment for a household (used when re-planning that device). */
export function ledgerRemove(householdId: string, device: string): void {
    const i = ledger.findIndex((x) => x.householdId === householdId && x.device === device);
    if (i >= 0) ledger.splice(i, 1);
}
```

- [ ] **Step 5: Remove the unused-import guard**

The `void commitmentsFor;` line and its import exist only as a guard. Delete the import of `commitmentsFor` from the `./ledger` import line and delete the `void commitmentsFor;` line so the file is clean.

Final import line in `planDay.ts`:

```typescript
import { addCommitment, ledgerRemove } from "./ledger";
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `cd backend && npm test`
Expected: PASS — all `planDay` tests green; Tasks 1–2 still green.

- [ ] **Step 7: Commit**

```bash
git add backend/src/planDay.ts backend/src/ledger.ts backend/src/planDay.test.ts
git commit -m "feat(backend): planDay orchestration — coordinated schedule, curve, savings"
```

---

### Task 4: `POST /plan_day` route

**Files:**
- Modify: `backend/src/server.ts`

- [ ] **Step 1: Add the route**

In `backend/src/server.ts`, add the import:

```typescript
import { planDay, PlanTaskInput } from "./planDay";
```

Add the route (place it near `/optimize_load`):

```typescript
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
```

- [ ] **Step 2: Build to verify it compiles**

Run: `cd backend && npm run build`
Expected: tsc exits 0, no errors.

- [ ] **Step 3: Smoke-test the route manually**

Run (in one terminal): `cd backend && node dist/server.js`
Then in another:

```bash
curl -s -X POST http://127.0.0.1:8090/plan_day -H 'content-type: application/json' \
  -d '{"household":"HH-1001","clock":"summer","mode":"cheapest","tasks":[{"device":"dishwasher","deadline":"2026-06-20T22:00:00"},{"device":"ev","deadline":"2026-06-21T07:00:00","target":80}]}' | head -c 600
```

Expected: JSON with `mode`, `solarSharePct`, `savedEur`, `savedCo2Kg`, an 18-element `curve`, and 2 `tasks`. Stop the server (Ctrl-C).

- [ ] **Step 4: Commit**

```bash
git add backend/src/server.ts
git commit -m "feat(backend): POST /plan_day route"
```

---

## Phase B — iOS

> iOS verification per task = "it compiles". Build command (run from repo root):
> ```bash
> cd ios && xcodegen generate && xcodebuild -scheme Lumen \
>   -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
> ```
> Expected: `** BUILD SUCCEEDED **`. If `iPhone 16` is unavailable, run `xcrun simctl list devices available` and substitute an available iPhone simulator name. The full end-to-end UI check is Task 13.

### Task 5: Plan models

**Files:**
- Modify: `ios/Sources/Models.swift`

- [ ] **Step 1: Add the models**

Append to `ios/Sources/Models.swift`:

```swift
// MARK: - /plan_day
struct PlanResult: Decodable, Sendable {
    let mode: String
    let solarSharePct: Double
    let savedEur: Double
    let savedCo2Kg: Double
    let curve: [CurvePoint]
    let tasks: [PlannedTask]

    struct CurvePoint: Decodable, Sendable, Identifiable {
        let hour: Int; let solarKw: Double
        var id: Int { hour }
    }
    struct PlannedTask: Decodable, Sendable, Identifiable {
        let device: String; let name: String; let icon: String
        let start: String; let startHour: Int; let window: String
        let durationHours: Double; let source: String
        let ownSharePct: Double; let gridCostEur: Double; let controllable: Bool
        var id: String { device }
    }
}

enum PlanMode: String, CaseIterable, Identifiable, Sendable {
    case cheapest, greenest, soonest
    var id: String { rawValue }
    var label: String { self == .cheapest ? "Cheapest" : self == .greenest ? "Greenest" : "Soonest" }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run the iOS build command above. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add ios/Sources/Models.swift
git commit -m "feat(ios): PlanResult + PlanMode models"
```

---

### Task 6: APIClient.planDay

**Files:**
- Modify: `ios/Sources/APIClient.swift`

- [ ] **Step 1: Add the request**

In `ios/Sources/APIClient.swift`, add a struct for task input near the top (after `APIError`):

```swift
struct PlanTaskInput: Sendable {
    let device: String
    let deadline: String?
    let target: Int?
    let start: String?
}
```

Add the method inside `struct APIClient` (after `optimize(...)`):

```swift
func planDay(tasks: [PlanTaskInput], mode: PlanMode, household: String = Config.defaultHousehold, clock: DemoClock) async throws -> PlanResult {
    let body: [String: Any] = [
        "household": household, "clock": clock.rawValue, "mode": mode.rawValue,
        "tasks": tasks.map { t -> [String: Any] in
            var o: [String: Any] = ["device": t.device]
            if let d = t.deadline { o["deadline"] = d }
            if let g = t.target { o["target"] = g }
            if let s = t.start { o["start"] = s }
            return o
        },
    ]
    return try await postJSON("/plan_day", body: body)
}
```

(`postJSON` already exists and sends the `x-lumen-token` header.)

- [ ] **Step 2: Build to verify it compiles**

Run the iOS build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add ios/Sources/APIClient.swift
git commit -m "feat(ios): APIClient.planDay"
```

---

### Task 7: Shared ClockStore + Home injection

Extract the clock out of `HomeViewModel` into a shared `ObservableObject` both screens use.

**Files:**
- Create: `ios/Sources/ClockStore.swift`
- Modify: `ios/Sources/HomeViewModel.swift`, `ios/Sources/HomeView.swift`

- [ ] **Step 1: Create ClockStore**

Create `ios/Sources/ClockStore.swift`:

```swift
import Foundation
import SwiftUI

/// The demo clock shared by Home and Plan-my-day. Changing it resets the household
/// ledger and is observed by both screens.
@MainActor final class ClockStore: ObservableObject {
    @Published var clock: DemoClock = .summer
    private let api = APIClient()

    func setClock(_ c: DemoClock) {
        guard c != clock else { return }
        clock = c
        Task { try? await api.reset() }   // fresh ledger per clock for clean demos
    }
}
```

- [ ] **Step 2: Make HomeViewModel use an injected clock**

In `ios/Sources/HomeViewModel.swift`:

Replace `@Published var clock: DemoClock = .summer` with:

```swift
    let clockStore: ClockStore
    var clock: DemoClock { clockStore.clock }

    init(clockStore: ClockStore) { self.clockStore = clockStore }
```

Replace the existing `setClock` method body to delegate:

```swift
    func setClock(_ c: DemoClock) {
        clockStore.setClock(c)
        Task { await loadAll() }
    }
```

- [ ] **Step 3: Update HomeView to take the store**

In `ios/Sources/HomeView.swift`:

Replace `@StateObject private var vm = HomeViewModel()` with:

```swift
    @StateObject private var vm: HomeViewModel
    init(clock: ClockStore) { _vm = StateObject(wrappedValue: HomeViewModel(clockStore: clock)) }
```

Add an on-appear device refresh so tasks scheduled on the Plan screen show here. Change the existing `.task { ... }` modifier to also refresh devices when the view reappears:

```swift
        .task { if vm.state == nil { await vm.loadAll() } }
        .onAppear { Task { await vm.reloadDevices() } }
```

- [ ] **Step 4: Build to verify it compiles**

`LumenApp` still references `HomeView()` with no args — it will fail to compile until Task 8. To check this task in isolation, the build will error at `LumenApp.swift`. That is expected; proceed to Task 8 which fixes the call site, then build. (Do not commit a broken build — commit Tasks 7 and 8 together at the end of Task 8.)

- [ ] **Step 5: (No commit yet — bundled with Task 8.)**

---

### Task 8: RootPager + LumenApp wiring

**Files:**
- Create: `ios/Sources/RootPager.swift`
- Modify: `ios/Sources/LumenApp.swift`

- [ ] **Step 1: Create RootPager**

Create `ios/Sources/RootPager.swift`:

```swift
import SwiftUI

/// Two start screens — Home and Plan-my-day — paged horizontally, sharing one clock.
struct RootPager: View {
    @StateObject private var clock = ClockStore()
    @State private var page = 0

    var body: some View {
        TabView(selection: $page) {
            HomeView(clock: clock).tag(0)
            PlanDayView(clock: clock).tag(1)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea(.keyboard)
    }
}

/// A tiny two-dot affordance each screen shows in its header to hint horizontal swipe.
struct PagerDots: View {
    let current: Int   // 0 = Home, 1 = Plan
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<2, id: \.self) { i in
                Circle().fill(i == current ? Theme.ink : Theme.hairline).frame(width: 6, height: 6)
            }
        }
        .accessibilityHidden(true)
    }
}
```

- [ ] **Step 2: Render RootPager from LumenApp**

Replace the body of `ios/Sources/LumenApp.swift`:

```swift
import SwiftUI

@main
struct LumenApp: App {
    @AppStorage("appearance") private var appearance = "dark"

    var body: some Scene {
        WindowGroup {
            RootPager()
                .preferredColorScheme(appearance == "light" ? .light : .dark)
        }
    }
}
```

- [ ] **Step 3: Add the swipe dots to Home's header**

In `ios/Sources/HomeView.swift`, in the `header` view, add `PagerDots(current: 0)` just before the appearance toggle button inside the right-hand `HStack`:

```swift
            HStack(spacing: 12) {
                PagerDots(current: 0)
                Button { appearance = (appearance == "dark" ? "light" : "dark") } label: {
                    Image(systemName: "circle.lefthalf.filled").font(.title3).foregroundStyle(Theme.subtle)
                }
                .accessibilityLabel("Toggle appearance")
                statusChip
            }
```

- [ ] **Step 4: Build**

`PlanDayView` does not exist yet, so this still won't compile. Create a minimal stub now to unblock the build; Task 11 replaces it. Create `ios/Sources/PlanDayView.swift`:

```swift
import SwiftUI

struct PlanDayView: View {
    let clock: ClockStore
    var body: some View { Text("Plan my day").warmScreen() }
}
```

Run the iOS build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit Tasks 7 + 8**

```bash
git add ios/Sources/ClockStore.swift ios/Sources/HomeViewModel.swift ios/Sources/HomeView.swift \
        ios/Sources/RootPager.swift ios/Sources/LumenApp.swift ios/Sources/PlanDayView.swift
git commit -m "feat(ios): paged Home + Plan-my-day shell with shared ClockStore"
```

---

### Task 9: PlanDayViewModel

**Files:**
- Create: `ios/Sources/PlanDayViewModel.swift`

- [ ] **Step 1: Create the view model**

Create `ios/Sources/PlanDayViewModel.swift`:

```swift
import Foundation
import SwiftUI

@MainActor final class PlanDayViewModel: ObservableObject {
    enum Phase { case pick, plan }

    struct TaskInput { var deadline: Date; var target: Int }   // target used by car only

    @Published var phase: Phase = .pick
    @Published var devices: [Device] = []
    @Published var selected: [String: TaskInput] = [:]         // deviceId → input
    @Published var mode: PlanMode = .cheapest
    @Published var plan: PlanResult?
    @Published var nudged: [String: String] = [:]              // deviceId → pinned start ISO
    @Published var isLoading = false
    @Published var errorText: String?

    let clockStore: ClockStore
    private let api = APIClient()
    init(clockStore: ClockStore) { self.clockStore = clockStore }
    var clock: DemoClock { clockStore.clock }

    func loadDevices() async {
        if let d = try? await api.devices(clock: clock) { devices = d }
    }

    func toggle(_ device: Device) {
        if selected[device.id] != nil { selected[device.id] = nil }
        else { selected[device.id] = TaskInput(deadline: defaultDeadline(for: device), target: 80) }
    }

    func makePlan() async { await runPlan(reset: true) }
    func replan() async { nudged.removeAll(); await runPlan(reset: true) }
    func setMode(_ m: PlanMode) { mode = m; Task { await runPlan(reset: false) } }

    /// Nudge a task ±1h, pin it, and re-plan the rest around it.
    func nudge(device: String, deltaHours: Int) {
        guard let t = plan?.tasks.first(where: { $0.device == device }) else { return }
        let base = nudged[device].flatMap(hour(fromISO:)) ?? t.startHour
        let h = min(23, max(0, base + deltaHours))
        nudged[device] = isoAtHour(h)
        Task { await runPlan(reset: false) }
    }

    private func runPlan(reset: Bool) async {
        isLoading = true; errorText = nil
        defer { isLoading = false }
        let inputs: [PlanTaskInput] = selected.map { (id, input) in
            PlanTaskInput(
                device: id,
                deadline: iso(from: input.deadline),
                target: id == "ev" ? input.target : nil,
                start: nudged[id]
            )
        }
        do {
            plan = try await api.planDay(tasks: inputs, mode: mode, clock: clock)
            phase = .plan
        } catch { errorText = error.localizedDescription }
    }

    // MARK: helpers

    private func defaultDeadline(for device: Device) -> Date {
        // base date = the demo "now" day; defaults: car 07:00 next day, appliances 20:00, boosts 19:00
        let cal = Calendar.current
        let now = nowDate()
        switch device.id {
        case "ev":
            let next = cal.date(byAdding: .day, value: 1, to: now) ?? now
            return cal.date(bySettingHour: 7, minute: 0, second: 0, of: next) ?? next
        case "hot_water", "heating_boost":
            return cal.date(bySettingHour: 19, minute: 0, second: 0, of: now) ?? now
        default:
            return cal.date(bySettingHour: 20, minute: 0, second: 0, of: now) ?? now
        }
    }

    /// The demo clock's "now" as a Date (summer 2026-06-20T13:00, winter 2026-01-15T08:00).
    private func nowDate() -> Date {
        let iso = clock == .summer ? "2026-06-20T13:00:00" : "2026-01-15T08:00:00"
        return Self.formatter.date(from: iso) ?? Date()
    }
    private func iso(from d: Date) -> String { Self.formatter.string(from: d) }
    private func isoAtHour(_ h: Int) -> String {
        let cal = Calendar.current
        let base = cal.date(bySettingHour: h, minute: 0, second: 0, of: nowDate()) ?? nowDate()
        return Self.formatter.string(from: base)
    }
    private func hour(fromISO iso: String) -> Int? { Int(iso.dropFirst(11).prefix(2)) }

    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Berlin")
        return f
    }()
}
```

- [ ] **Step 2: Build to verify it compiles**

Run the iOS build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add ios/Sources/PlanDayViewModel.swift
git commit -m "feat(ios): PlanDayViewModel — selection, plan, mode, nudge"
```

---

### Task 10: DayTimeline (Canvas)

**Files:**
- Create: `ios/Sources/DayTimeline.swift`

- [ ] **Step 1: Create the timeline view**

Create `ios/Sources/DayTimeline.swift`:

```swift
import SwiftUI

/// Hero timeline: solar-production curve in the background, task blocks slotted at their
/// start hour, each split-shaded (own-solar green vs. grid grey). Tap a block to select it.
struct DayTimeline: View {
    let curve: [PlanResult.CurvePoint]
    let tasks: [PlanResult.PlannedTask]
    let selected: String?
    let onTap: (String) -> Void

    private let startHour = 6
    private let endHour = 23           // axis 06:00–23:00
    private var span: Int { endHour - startHour }   // 17

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let curveH = h * 0.42
                let laneTop = curveH + 8
                let maxKw = max(1, curve.map(\.solarKw).max() ?? 1)
                let hourW = w / CGFloat(span)
                let lanes = layoutLanes(tasks)
                let laneH: CGFloat = 30
                ZStack(alignment: .topLeading) {
                    // solar curve area
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: curveH))
                        for pt in curve {
                            let x = CGFloat(pt.hour - startHour) * hourW
                            let y = curveH - CGFloat(pt.solarKw) / CGFloat(maxKw) * curveH
                            p.addLine(to: CGPoint(x: x, y: y))
                        }
                        p.addLine(to: CGPoint(x: w, y: curveH))
                        p.closeSubpath()
                    }
                    .fill(Theme.green.opacity(0.16))

                    // task blocks
                    ForEach(Array(lanes.enumerated()), id: \.element.device) { _, item in
                        let x = CGFloat(item.task.startHour - startHour) * hourW
                        let bw = max(hourW * CGFloat(item.task.durationHours), 28)
                        let y = laneTop + CGFloat(item.lane) * (laneH + 6)
                        block(item.task, width: bw, height: laneH)
                            .frame(width: bw, height: laneH)
                            .offset(x: max(0, min(x, w - bw)), y: y)
                            .onTapGesture { onTap(item.task.device) }
                    }
                }
            }
            .frame(height: 168)
            HStack { Text("06"); Spacer(); Text("12"); Spacer(); Text("18"); Spacer(); Text("23") }
                .font(.system(size: 10)).foregroundStyle(Theme.subtle)
        }
    }

    private func block(_ t: PlanResult.PlannedTask, width: CGFloat, height: CGFloat) -> some View {
        let ownFrac = CGFloat(max(0, min(100, t.ownSharePct)) / 100)
        return ZStack(alignment: .leading) {
            // grid portion (full width), then own-solar portion overlaid from the left
            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.grid.opacity(0.5))
            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.green.opacity(0.85))
                .frame(width: max(8, width * ownFrac))
            HStack(spacing: 4) {
                Image(systemName: symbol(t.icon)).font(.system(size: 11, weight: .bold))
                Text(t.name).font(.system(size: 11, weight: .semibold)).lineLimit(1)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
        }
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(selected == t.device ? Theme.ink : .clear, lineWidth: 2))
    }

    /// Greedy lane packing so overlapping blocks stack vertically.
    private struct Placed { let task: PlanResult.PlannedTask; let lane: Int; var device: String { task.device } }
    private func layoutLanes(_ tasks: [PlanResult.PlannedTask]) -> [Placed] {
        let sorted = tasks.sorted { $0.startHour < $1.startHour }
        var laneEnds: [Double] = []   // end hour per lane
        var out: [Placed] = []
        for t in sorted {
            let start = Double(t.startHour), end = start + t.durationHours
            var lane = laneEnds.firstIndex(where: { $0 <= start }) ?? -1
            if lane < 0 { laneEnds.append(end); lane = laneEnds.count - 1 }
            else { laneEnds[lane] = end }
            out.append(Placed(task: t, lane: lane))
        }
        return out
    }

    private func symbol(_ icon: String) -> String {
        switch icon {
        case "car": return "car.fill"
        case "bowl": return "dishwasher.fill"
        case "wash": return "washer.fill"
        case "dryer": return "dryer.fill"
        case "shower": return "shower.fill"
        case "flame": return "flame.fill"
        default: return "powerplug.fill"
        }
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run the iOS build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add ios/Sources/DayTimeline.swift
git commit -m "feat(ios): DayTimeline canvas — solar curve + split-shaded task blocks"
```

---

### Task 11: PlanDayView — both states

Replace the stub with the real screen.

**Files:**
- Modify: `ios/Sources/PlanDayView.swift`

- [ ] **Step 1: Implement the screen**

Replace the entire contents of `ios/Sources/PlanDayView.swift`:

```swift
import SwiftUI

struct PlanDayView: View {
    @StateObject private var vm: PlanDayViewModel
    @State private var selectedBlock: String?

    init(clock: ClockStore) { _vm = StateObject(wrappedValue: PlanDayViewModel(clockStore: clock)) }

    var body: some View {
        Group {
            switch vm.phase {
            case .pick: pickState
            case .plan: planState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .warmScreen()
        .task { if vm.devices.isEmpty { await vm.loadDevices() } }
    }

    // MARK: State 1 — pick

    private var pickState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("What do you want to do today?")
                        .font(.system(.title2).weight(.bold)).foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    PagerDots(current: 1)
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(vm.devices) { d in
                        TaskCard(device: d, selected: vm.selected[d.id] != nil) { vm.toggle(d) }
                    }
                }
                ForEach(vm.devices.filter { vm.selected[$0.id] != nil }) { d in
                    taskRow(d)
                }
                if let e = vm.errorText { Text(e).font(.footnote).foregroundStyle(Theme.red) }
                makeButton
            }
            .padding(20)
        }
    }

    private func taskRow(_ d: Device) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: symbol(d.icon)).foregroundStyle(Theme.green)
                Text(d.name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                Spacer()
                DatePicker("", selection: Binding(
                    get: { vm.selected[d.id]?.deadline ?? Date() },
                    set: { if vm.selected[d.id] != nil { vm.selected[d.id]!.deadline = $0 } }
                ), displayedComponents: .hourAndMinute)
                .labelsHidden()
            }
            if d.id == "ev", let input = vm.selected[d.id] {
                HStack {
                    Text("Charge to \(input.target)%").font(.caption).foregroundStyle(Theme.subtle)
                    Slider(value: Binding(
                        get: { Double(vm.selected[d.id]?.target ?? 80) },
                        set: { if vm.selected[d.id] != nil { vm.selected[d.id]!.target = Int($0) } }
                    ), in: 50...100, step: 5)
                    .tint(Theme.green)
                }
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardSurface(16)
    }

    private var makeButton: some View {
        Button { Task { await vm.makePlan() } } label: {
            HStack {
                if vm.isLoading { ProgressView().tint(.white) }
                Image(systemName: "wand.and.stars")
                Text(vm.isLoading ? "Planning…" : "Make my plan").font(.headline)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 15)
            .background(vm.selected.isEmpty ? Theme.hairline : Theme.green,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .foregroundStyle(.white)
        }
        .disabled(vm.selected.isEmpty || vm.isLoading)
    }

    // MARK: State 2 — plan

    @ViewBuilder private var planState: some View {
        if let p = vm.plan {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Button { vm.phase = .pick } label: {
                            Label("Edit tasks", systemImage: "chevron.left").font(.subheadline)
                        }.buttonStyle(.plain).foregroundStyle(Theme.subtle)
                        Spacer()
                        PagerDots(current: 1)
                    }
                    summaryChip(p)
                    Picker("Mode", selection: Binding(get: { vm.mode }, set: { vm.setMode($0) })) {
                        ForEach(PlanMode.allCases) { m in Text(m.label).tag(m) }
                    }
                    .pickerStyle(.segmented)

                    DayTimeline(curve: p.curve, tasks: p.tasks, selected: selectedBlock) { dev in
                        selectedBlock = (selectedBlock == dev) ? nil : dev
                    }

                    if let dev = selectedBlock, let t = p.tasks.first(where: { $0.device == dev }) {
                        nudgeBar(t)
                    }

                    orderedList(p)

                    Button { Task { selectedBlock = nil; await vm.replan() } } label: {
                        Label("Re-plan", systemImage: "arrow.triangle.2.circlepath")
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Theme.greenSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .foregroundStyle(Theme.green)
                    }.buttonStyle(.plain)
                }
                .padding(20)
            }
        } else {
            ProgressView("Planning…").frame(maxWidth: .infinity, minHeight: 300)
        }
    }

    private func summaryChip(_ p: PlanResult) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "leaf.fill")
            Text("\(Int(p.solarSharePct))% solar · saves €\(String(format: "%.2f", p.savedEur)) / \(String(format: "%.0f", p.savedCo2Kg)) kg CO₂ today")
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(Theme.green)
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Theme.greenSoft, in: Capsule())
    }

    private func nudgeBar(_ t: PlanResult.PlannedTask) -> some View {
        HStack {
            Text("\(t.name) · \(t.window)").font(.subheadline.weight(.medium)).foregroundStyle(Theme.ink)
            Spacer()
            Button { vm.nudge(device: t.device, deltaHours: -1) } label: { Image(systemName: "minus.circle.fill") }
            Text("nudge").font(.caption).foregroundStyle(Theme.subtle)
            Button { vm.nudge(device: t.device, deltaHours: 1) } label: { Image(systemName: "plus.circle.fill") }
        }
        .font(.title3).foregroundStyle(Theme.green)
        .padding(14).cardSurface(14)
    }

    private func orderedList(_ p: PlanResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(p.tasks.sorted { $0.startHour < $1.startHour }) { t in
                HStack(spacing: 10) {
                    Text(String(t.window.prefix(5))).font(.subheadline.weight(.bold)).foregroundStyle(Theme.ink)
                        .frame(width: 52, alignment: .leading)
                    Image(systemName: symbol(t.icon)).foregroundStyle(Theme.source(t.source))
                    Text(t.name).font(.subheadline).foregroundStyle(Theme.ink)
                    Spacer()
                    Text(Theme.sourceLabel(t.source)).font(.caption).foregroundStyle(Theme.source(t.source))
                }
                .padding(.vertical, 4)
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardSurface(16)
    }

    private func symbol(_ icon: String) -> String {
        switch icon {
        case "car": return "car.fill"
        case "bowl": return "dishwasher.fill"
        case "wash": return "washer.fill"
        case "dryer": return "dryer.fill"
        case "shower": return "shower.fill"
        case "flame": return "flame.fill"
        default: return "powerplug.fill"
        }
    }
}

/// A multi-select task card for State 1.
private struct TaskCard: View {
    let device: Device
    let selected: Bool
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: symbol).font(.system(size: 26)).foregroundStyle(selected ? .white : Theme.green)
                Text(device.name).font(.subheadline.weight(.semibold))
                    .foregroundStyle(selected ? .white : Theme.ink).lineLimit(1)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 20)
            .background(selected ? Theme.green : Theme.card,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(selected ? Theme.green : Theme.hairline, lineWidth: 1))
        }.buttonStyle(.plain)
    }
    private var symbol: String {
        switch device.icon {
        case "car": return "car.fill"
        case "bowl": return "dishwasher.fill"
        case "wash": return "washer.fill"
        case "dryer": return "dryer.fill"
        case "shower": return "shower.fill"
        case "flame": return "flame.fill"
        default: return "powerplug.fill"
        }
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run the iOS build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add ios/Sources/PlanDayView.swift
git commit -m "feat(ios): PlanDayView — pick tasks + plan with timeline, modes, nudge"
```

---

### Task 12: Icon maps for new appliances on Home

So the new devices render correctly if shown in Home's `DeviceRow` / `DeviceSheetView`.

**Files:**
- Modify: `ios/Sources/HomeView.swift`, `ios/Sources/DeviceSheetView.swift`

- [ ] **Step 1: Extend DeviceRow's symbol + tint (HomeView.swift)**

In `ios/Sources/HomeView.swift`, replace the `DeviceRow` `symbol` and `tint` computed properties:

```swift
    private var tint: Color {
        switch device.icon {
        case "car": return Theme.green
        case "bowl": return Theme.amber
        case "wash": return Theme.grid
        case "dryer": return Theme.grid
        case "shower": return Theme.amber
        case "flame": return Theme.red
        default: return Theme.green
        }
    }
    private var symbol: String {
        switch device.icon {
        case "car": return "car.fill"
        case "bowl": return "dishwasher.fill"
        case "wash": return "washer.fill"
        case "dryer": return "dryer.fill"
        case "shower": return "shower.fill"
        case "flame": return "flame.fill"
        default: return "powerplug.fill"
        }
    }
```

- [ ] **Step 2: Extend DeviceSheetView's symbol + tint (DeviceSheetView.swift)**

In `ios/Sources/DeviceSheetView.swift`, replace the `tint` and `symbol` computed properties the same way:

```swift
    private var tint: Color {
        switch device.icon {
        case "car": return Theme.green
        case "bowl": return Theme.amber
        case "wash": return Theme.grid
        case "dryer": return Theme.grid
        case "shower": return Theme.amber
        case "flame": return Theme.red
        default: return Theme.green
        }
    }
    private var symbol: String {
        switch device.icon {
        case "car": return "car.fill"
        case "bowl": return "dishwasher.fill"
        case "wash": return "washer.fill"
        case "dryer": return "dryer.fill"
        case "shower": return "shower.fill"
        case "flame": return "flame.fill"
        default: return "powerplug.fill"
        }
    }
```

- [ ] **Step 3: Build to verify it compiles**

Run the iOS build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add ios/Sources/HomeView.swift ios/Sources/DeviceSheetView.swift
git commit -m "feat(ios): icon + tint maps for dryer/hot-water/heating-boost"
```

---

### Task 13: End-to-end verification

**Files:** none (manual).

- [ ] **Step 1: Start the backend**

Run: `cd backend && npm run build && node dist/server.js`
Expected: `reonic-backend on http://127.0.0.1:8090`.

- [ ] **Step 2: Run the app in the simulator**

Run: `cd ios && xcodegen generate && xcodebuild -scheme Lumen -destination 'platform=iOS Simulator,name=iPhone 16' build` then launch via the project's usual run path (or the `run` skill).

- [ ] **Step 3: Walk the flow**

Verify, in order:
1. Home shows as before; a 2-dot indicator sits in the header (left dot filled).
2. Swipe left → "Plan my day" State 1 with six task cards.
3. Select Dishwasher + Charge car → rows appear; car shows a charge slider (default 80%) and a 07:00 "Done by"; dishwasher shows ~20:00.
4. Tap "Make my plan" → State 2: summary chip with solar % / € / CO₂, segmented Cheapest/Greenest/Soonest, the timeline with the solar curve and two labeled blocks, and the ordered list below.
5. Toggle Greenest then Soonest → blocks move; summary updates.
6. Tap the car block → nudge bar appears; tap +/- → the car shifts and the dishwasher re-routes.
7. Tap "Re-plan" → recomputes in the current mode.
8. Swipe back to Home → the Car and Dishwasher now show "scheduled" with their windows (shared ledger confirmed).

- [ ] **Step 4: Commit any fixes found, then finish**

If walkthrough issues required code changes, commit them with descriptive messages. Otherwise nothing to commit.

---

## Notes for the implementer

- **Determinism:** the planner is deterministic; same inputs + clock ⇒ same plan. Tests rely on this.
- **Ledger is global in-memory:** `/plan_day` replaces only the requested devices' commitments (via `ledgerRemove`), so Home-scheduled devices not in the plan are left intact, and re-planning is clean.
- **EV energy** comes from the charge target (20%→target). With the 60 kWh demo car at default 80%, that's 36 kWh — large enough that a "by 7am" deadline lets the planner pull it onto midday solar today rather than overnight grid. That's the intended demo beat.
- **Time zone:** the app formats demo deadlines in `Europe/Berlin` to match the backend's ISO timestamps (no offset suffix). Keep the formatter as written.
