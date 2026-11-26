import { test } from "node:test";
import assert from "node:assert/strict";
import { computeDaysUntilNext } from "./anniversary-math";

test("yearly: same day → 0", () => {
  assert.equal(computeDaysUntilNext("2024-05-22", "yearly", "2026-05-22"), 0);
});

test("yearly: two days before", () => {
  assert.equal(computeDaysUntilNext("2024-05-22", "yearly", "2026-05-20"), 2);
});

test("yearly: day after rolls to next year", () => {
  assert.equal(computeDaysUntilNext("2024-05-22", "yearly", "2026-05-23"), 364);
});

test("monthly: same day → 0", () => {
  assert.equal(computeDaysUntilNext("2024-01-15", "monthly", "2026-10-15"), 0);
});

test("monthly: after day rolls to next month", () => {
  assert.equal(computeDaysUntilNext("2024-01-15", "monthly", "2026-10-16"), 30);
});

test("invalid base date → null", () => {
  assert.equal(computeDaysUntilNext("not-a-date", "yearly", "2026-10-12"), null);
});
