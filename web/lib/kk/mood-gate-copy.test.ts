import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

import { moodGateMessage } from "./mood-gate-copy";

test("mood gate never shows raw profile_missing or other machine codes", () => {
  const samples = [
    "profile_missing",
    "PROFILE_MISSING",
    '{"code":"P0001","message":"profile_missing"}',
    "partner_profile_missing",
    "not_authenticated",
    "not authenticated",
    "invalid_mood",
    "mood_gate_before_0600_hkt",
    "mood_date_must_be_today_hkt",
    "not_paired",
    "The network connection was lost.",
    "kk_set_daily_mood_failed",
  ];
  for (const raw of samples) {
    const shown = moodGateMessage(raw);
    assert.equal(shown.toLowerCase().includes("profile_missing"), false, shown);
    assert.equal(shown.includes("_"), false, shown);
    assert.equal(shown.toLowerCase().includes("network"), false, shown);
    assert.equal(
      [...shown].some((ch) => {
        const cp = ch.codePointAt(0) ?? 0;
        return cp >= 0x4e00 && cp <= 0x9fff;
      }),
      true,
      shown,
    );
  }

  assert.equal(moodGateMessage("profile_missing"), "未完成註冊 — 再試一次");
  assert.equal(
    moodGateMessage("partner_profile_missing"),
    "對方未完成註冊 — 等對方再開一次",
  );
  assert.equal(moodGateMessage("not_authenticated"), "未登入 — 重新登入");
  assert.equal(moodGateMessage("invalid_mood"), "呢個心情伺服器唔收 — 再揀一次");
  assert.equal(
    moodGateMessage("mood_gate_before_0600_hkt"),
    "香港時間 06:00 之前伺服器唔收心情。",
  );
  assert.equal(moodGateMessage("mood_date_must_be_today_hkt"), "日子對唔上 — 再試一次");
  assert.equal(moodGateMessage("not_paired"), "未配對 — 請先配對");
  assert.equal(moodGateMessage("The network connection was lost."), "暫時做唔到 — 再試一次");
  assert.equal(
    moodGateMessage("香港時間 06:00 之前伺服器唔收心情。"),
    "香港時間 06:00 之前伺服器唔收心情。",
  );
  assert.equal(
    moodGateMessage("伺服器回覆唔喺心情白名單，冇採用。"),
    "伺服器回覆唔喺心情白名單，冇採用。",
  );
  assert.equal(
    moodGateMessage("出錯 profile_missing 請再試"),
    "未完成註冊 — 再試一次",
  );
});

test("mood page has no cheer step and maps gate errors", () => {
  const page = readFileSync(new URL("../../app/mood/page.tsx", import.meta.url), "utf8");
  assert.equal(page.includes("打氣"), false);
  assert.equal(page.includes("cheerSkip"), false);
  assert.equal(page.includes("doneMood"), false);
  assert.equal(page.includes("profile_missing"), false);
  assert.match(page, /moodGateMessage\(/);
  assert.match(page, /setMoodForToday\(picked\)/);
  assert.match(page, /router\.replace\("\/chat"\)/);
});

test("sixth mood lock stays 有啲 + U+6530 via fromCodePoint", () => {
  const api = readFileSync(new URL("./api.ts", import.meta.url), "utf8");
  const lock = api.match(
    /const SIXTH_MOOD = \("有啲" \+ String\.fromCodePoint\(0x6530\)\) as MoodId;/,
  );
  assert.ok(lock);
  assert.equal(api.includes("String.fromCodePoint(0x6536)"), false);
  assert.equal(api.includes("String.fromCodePoint(0x6520)"), false);
  assert.equal(api.includes("String.fromCodePoint(0x652F)"), false);
  assert.equal(api.includes("String.fromCodePoint(0x652f)"), false);
});
