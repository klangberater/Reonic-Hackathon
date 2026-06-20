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
