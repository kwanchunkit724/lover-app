#!/usr/bin/env node
// One-off: extract 120 DateCards from iOS Catalogs.swift, emit them as
// JSON to stdout. Pipe into lib/services/activities.ts manually.
//
// Usage (from web/):
//   node scripts/extract-cards.mjs > /tmp/cards.json

import { readFileSync } from "node:fs";

const SRC = "../ios/LoverApp/Core/Catalogs.swift";
const raw = readFileSync(SRC, "utf8");

// Each DateCard spans 2-3 lines. Match the full record from `DateCard(`
// up to the closing `)`. Field order is fixed in the source.
const re =
  /DateCard\(\s*id:\s*(\d+),\s*title:\s*"([^"]+)",\s*detail:\s*"([^"]+)",\s*mood:\s*"([^"]+)",\s*kaomoji:\s*"([^"]+)",\s*tint:\s*\.\w+,\s*cost:\s*"([^"]+)"\s*\)/g;

const out = [];
for (const m of raw.matchAll(re)) {
  out.push({
    id: Number(m[1]),
    title: m[2],
    detail: m[3],
    mood: m[4],
    kaomoji: m[5],
    cost: m[6],
  });
}

if (out.length !== 120) {
  console.error(`WARN: parsed ${out.length} cards, expected 120`);
}
console.log(JSON.stringify(out, null, 2));
