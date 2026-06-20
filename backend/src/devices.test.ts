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
