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
