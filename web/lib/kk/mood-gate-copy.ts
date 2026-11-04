/**
 * Copy for the daily mood gate. Postgres `raise exception` codes such as
 * `profile_missing` stay off the screen.
 *
 * Aligned with iOS `MoodGateCopy` on the mood-gate fix (PR #6). Check
 * `partner_profile_missing` before `profile_missing` — the shorter key is a
 * substring of the longer one.
 */

export const moodGateMessage = (raw: string): string => {
  const lowered = raw.toLowerCase();
  if (lowered.includes("partner_profile_missing")) {
    return "對方未完成註冊 — 等對方再開一次";
  }
  if (lowered.includes("profile_missing")) {
    return "未完成註冊 — 再試一次";
  }
  if (lowered.includes("not_authenticated") || lowered.includes("not authenticated")) {
    return "未登入 — 重新登入";
  }
  if (lowered.includes("invalid_mood")) {
    return "呢個心情伺服器唔收 — 再揀一次";
  }
  if (lowered.includes("mood_gate_before_0600")) {
    return "香港時間 06:00 之前伺服器唔收心情。";
  }
  if (lowered.includes("mood_date_must_be_today")) {
    return "日子對唔上 — 再試一次";
  }
  if (lowered.includes("not_paired")) {
    return "未配對 — 請先配對";
  }
  if (isHumanCopy(raw)) return raw;
  return "暫時做唔到 — 再試一次";
};

/** Sentences we wrote ourselves. A CJK string that also carries a snake_case token is still a leaked code. */
const isHumanCopy = (raw: string): boolean => {
  let hasCJK = false;
  for (const ch of raw) {
    const cp = ch.codePointAt(0) ?? 0;
    if (cp >= 0x4e00 && cp <= 0x9fff) {
      hasCJK = true;
      break;
    }
  }
  return hasCJK && !containsMachineCode(raw);
};

const containsMachineCode = (raw: string): boolean => {
  let token = "";
  const isCode = (value: string): boolean => {
    if (!/^[a-z]/i.test(value)) return false;
    if (!value.includes("_")) return false;
    return /^[a-z0-9_]+$/i.test(value);
  };
  for (const ch of raw.toLowerCase()) {
    if (/^[a-z0-9_]$/.test(ch)) {
      token += ch;
    } else if (isCode(token)) {
      return true;
    } else {
      token = "";
    }
  }
  return isCode(token);
};
