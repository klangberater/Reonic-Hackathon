import test from "node:test";
import assert from "node:assert/strict";
import { contractSummary } from "./contract";

const HH = "HH-1001";
const NOW = "2026-06-20T13:00:00";

test("contract summary exposes terms and computes the notice deadline", () => {
  const c = contractSummary(HH, NOW);
  assert.equal(c.provider, "Enpal");
  assert.equal(c.tariffName, "Enpal FlexStrom Dynamic");
  assert.ok(c.contractEnd.length === 10 && c.contractStart.length === 10);
  assert.ok(c.termsText.length > 50);
  // noticeBy = contractEnd − noticePeriodWeeks (6 wk = 42 days). 2027-03-19 → 2027-02-05.
  assert.equal(c.noticeByDate, "2027-02-05");
  // deadline is after "now" in the demo, so positive days remaining
  assert.ok(c.daysUntilNoticeDeadline > 0, `got ${c.daysUntilNoticeDeadline}`);
  assert.ok(c.daysUntilEnd > c.daysUntilNoticeDeadline);
  assert.equal(c.inNoticeWindow, false);
});
