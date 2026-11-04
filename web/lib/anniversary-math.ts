// Pure anniversary countdown math — shared by the time service + unit tests.
// Mirrors ios/LoverApp/Models/Anniversary.swift nextOccurrence daysAway.

import dayjs from "dayjs";

/**
 * Days from today (start of local day) until the next occurrence of
 * `baseDateISO` under the given recurrence. Returns null if the base
 * date is invalid. Same-calendar-day → 0.
 */
export const computeDaysUntilNext = (
  baseDateISO: string,
  recur: "yearly" | "monthly",
  todayISO?: string,
): number | null => {
  const base = dayjs(baseDateISO);
  if (!base.isValid()) return null;
  const today = (todayISO ? dayjs(todayISO) : dayjs()).startOf("day");
  let next =
    recur === "yearly"
      ? base.year(today.year())
      : base.year(today.year()).month(today.month());
  if (next.isBefore(today)) {
    next = next.add(1, recur === "yearly" ? "year" : "month");
  }
  return next.diff(today, "day");
};
