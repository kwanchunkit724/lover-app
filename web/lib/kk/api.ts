/**
 * KK adapter — UI → existing web services where possible; mock elsewhere.
 * Function/type names mirror planned backend RPCs so iOS/web/backend stay aligned.
 *
 * Tables (backend, not implemented here):
 *   memory_items, want_you_know, want_you_know_reads, ai_usage, kaomoji_prefs
 * RPCs (kk_ prefix):
 *   kk_set_daily_mood — reuse users.mood / mood_updated_at; HKT day; 06:00 gate;
 *     moods: 開心/平靜/有啲攰/低落/掛住你/有啲煩
 *   kk_memory_* / kk_memory_from_chat (merge from chat, NO quota)
 *   kk_want_* + mark_read (want_you_know + want_you_know_reads)
 *   kk_ai_consume_and_run — ONLY user text + memory items (whitelist; never chat ciphertext)
 *   kk_ai_usage_get
 *   kk_kaomoji_prefs_get / kk_kaomoji_prefs_set
 * Also: couples.anniversary_iso nullable; messages.expires_at + 48h purge
 *   (text+media + memory_items source refs); pairing_codes 6-digit/10min;
 *   Apple + Email OTP only (no guest/anon).
 * Retired (do NOT touch): anniversaries, entries, play_history, meetups, checklist_items
 *
 * TODO before production: wire each export below to the real Supabase RPC/table;
 * enable Apple+Email OTP; disable anonymous; schedule 48h purge job.
 */

export type MemoryCategory = "日常" | "約會" | "計劃" | "其他";

/** Locked sixth mood: 有啲攰 (U+6530) per Chunkit decision 2026-11-02. Do NOT use 收 (U+6536) or 支 (U+652F). */
export type MoodId =
  | "開心"
  | "平靜"
  | "有啲攰"
  | "低落"
  | "掛住你"
  | "有啲煩";

export const MOODS: { id: MoodId; kao: string; en: string }[] = [
  { id: "開心", kao: "(ﾉ´ヮ`)ﾉ*:・ﾟ", en: "Happy" },
  { id: "平靜", kao: "(◕‿◕)", en: "Calm" },
  { id: "有啲攰", kao: "(・_・;)", en: "Meh" },
  { id: "低落", kao: "(´；ω；`)", en: "Low" },
  { id: "掛住你", kao: "(♡˙︶˙♡)", en: "Miss you" },
  { id: "有啲煩", kao: "(￣ヘ￣)", en: "Stressed" },
];

/** Mirrors planned memory_items row (UI shape). */
export interface MemoryItem {
  id: string;
  title: string;
  originalWords: string;
  category: MemoryCategory;
  note?: string;
  /** Auto-cleared after 48h (messages.expires_at / source ref purge). */
  sourceMessage?: string;
  sourceExpiresAt?: string;
  reminderAt?: string;
  createdAt: string;
}

/** Mirrors want_you_know + want_you_know_reads. */
export interface WantYouKnowItem {
  id: string;
  title?: string;
  content: string;
  deadline?: string;
  reminder: boolean;
  createdBy: "me" | "partner";
  readByMe: boolean;
  readByPartner: boolean;
  deletedByMe: boolean;
  deletedByPartner: boolean;
  createdAt: string;
}

/** @deprecated alias — prefer WantYouKnowItem */
export type TellItem = WantYouKnowItem;

export interface AiUsage {
  used: number;
  limit: number;
  remaining: number;
}

/** @deprecated alias — prefer AiUsage */
export type AiQuota = AiUsage;

export interface AiExpandResult {
  organized: string;
  plan: string;
}

const MEM_KEY = "kk.mock.memory_items";
const WANT_KEY = "kk.mock.want_you_know";
const AI_KEY = "kk.mock.ai_usage";
const MOOD_KEY = "kk.mock.daily_mood";
const DAY_KEY = "kk.mock.our_day";

const seedMemories = (): MemoryItem[] => [
  {
    id: "m1",
    title: "天台睇日落",
    originalWords: "記得第一次一齊爬上天台，你話個天似橙汁。",
    category: "約會",
    note: "想再去多一次",
    createdAt: "2026-09-12T18:00:00+08:00",
  },
  {
    id: "m2",
    title: "第一次一齊煮飯",
    originalWords: "火候太猛燒焦咗底，但你話係特調焦香。",
    category: "日常",
    createdAt: "2026-03-22T20:00:00+08:00",
  },
  {
    id: "m3",
    title: "下個月短途散心",
    originalWords: "講好想找個週末去近郊靜靜行下，唔使趕。",
    category: "計劃",
    note: "候補：西貢 / 大嶼山",
    createdAt: "2026-10-28T12:00:00+08:00",
  },
];

const seedWants = (): WantYouKnowItem[] => [
  {
    id: "t1",
    title: "加班通知",
    content: "星期三要加班，可能遲啲返。",
    deadline: "2026-11-05",
    reminder: true,
    createdBy: "me",
    readByMe: true,
    readByPartner: false,
    deletedByMe: false,
    deletedByPartner: false,
    createdAt: "2026-11-01T10:00:00+08:00",
  },
  {
    id: "t2",
    content: "雪櫃嗰支牛奶啱啱買，你鍾意飲可以飲。",
    reminder: false,
    createdBy: "partner",
    readByMe: true,
    readByPartner: true,
    deletedByMe: false,
    deletedByPartner: false,
    createdAt: "2026-10-30T09:00:00+08:00",
  },
];

const readJson = <T>(key: string, fallback: T): T => {
  if (typeof window === "undefined") return fallback;
  try {
    const raw = localStorage.getItem(key);
    if (!raw) return fallback;
    return JSON.parse(raw) as T;
  } catch {
    return fallback;
  }
};

const writeJson = (key: string, value: unknown) => {
  if (typeof window === "undefined") return;
  localStorage.setItem(key, JSON.stringify(value));
};

/** HKT calendar day id after 06:00 HKT gate (matches kk_set_daily_mood). */
export const hktMoodDayId = (now = new Date()): string => {
  const hkt = new Date(now.getTime() + 8 * 60 * 60 * 1000);
  if (hkt.getUTCHours() < 6) hkt.setUTCDate(hkt.getUTCDate() - 1);
  return hkt.toISOString().slice(0, 10);
};

// ── memory_items / kk_memory_* ──────────────────────────────────────────

/** TODO → kk_memory_list / select memory_items */
export const kk_memory_list = async (): Promise<MemoryItem[]> => {
  const items = readJson<MemoryItem[]>(MEM_KEY, []);
  if (items.length === 0) {
    writeJson(MEM_KEY, seedMemories());
    return seedMemories();
  }
  return items;
};

/** @deprecated prefer kk_memory_list */
export const listMemories = kk_memory_list;

/** TODO → kk_memory_create */
export const kk_memory_create = async (
  input: Omit<MemoryItem, "id" | "createdAt">,
): Promise<MemoryItem> => {
  const item: MemoryItem = {
    ...input,
    id: `m_${Date.now()}`,
    createdAt: new Date().toISOString(),
  };
  const items = await kk_memory_list();
  writeJson(MEM_KEY, [item, ...items]);
  return item;
};

/** @deprecated prefer kk_memory_create */
export const createMemory = kk_memory_create;

/**
 * Merge selected chat originals into a memory — NO AI quota.
 * TODO → kk_memory_from_chat (server never receives chat ciphertext; client
 * sends only the user-selected plaintext excerpts).
 */
export const kk_memory_from_chat = async (input: {
  title: string;
  originalWords: string;
  category: MemoryCategory;
  note?: string;
}): Promise<MemoryItem> =>
  kk_memory_create({
    ...input,
    sourceMessage: input.originalWords,
    sourceExpiresAt: new Date(Date.now() + 48 * 3600 * 1000).toISOString(),
  });

/** TODO → kk_memory_delete */
export const kk_memory_delete = async (id: string): Promise<void> => {
  writeJson(
    MEM_KEY,
    (await kk_memory_list()).filter((m) => m.id !== id),
  );
};

/** @deprecated prefer kk_memory_delete */
export const deleteMemory = kk_memory_delete;

// ── want_you_know / kk_want_* ───────────────────────────────────────────

/** TODO → kk_want_list */
export const kk_want_list = async (): Promise<WantYouKnowItem[]> => {
  const items = readJson<WantYouKnowItem[]>(WANT_KEY, []);
  if (items.length === 0) {
    writeJson(WANT_KEY, seedWants());
    return seedWants();
  }
  return items.filter((t) => !(t.deletedByMe && t.deletedByPartner));
};

/** @deprecated prefer kk_want_list */
export const listTells = kk_want_list;

/** TODO → kk_want_create */
export const kk_want_create = async (
  input: Pick<WantYouKnowItem, "title" | "content" | "deadline" | "reminder">,
): Promise<WantYouKnowItem> => {
  const item: WantYouKnowItem = {
    ...input,
    id: `t_${Date.now()}`,
    createdBy: "me",
    readByMe: true,
    readByPartner: false,
    deletedByMe: false,
    deletedByPartner: false,
    createdAt: new Date().toISOString(),
  };
  const items = await kk_want_list();
  writeJson(WANT_KEY, [item, ...items]);
  return item;
};

/** @deprecated prefer kk_want_create */
export const createTell = kk_want_create;

/** TODO → kk_want_mark_read → want_you_know_reads */
export const kk_want_mark_read = async (id: string): Promise<void> => {
  const all = readJson<WantYouKnowItem[]>(WANT_KEY, []);
  writeJson(
    WANT_KEY,
    all.map((t) => (t.id === id ? { ...t, readByMe: true } : t)),
  );
};

/** @deprecated prefer kk_want_mark_read */
export const markTellRead = kk_want_mark_read;

/** TODO → kk_want_delete (soft; persists until both delete) */
export const kk_want_delete = async (id: string): Promise<void> => {
  const all = readJson<WantYouKnowItem[]>(WANT_KEY, []);
  writeJson(
    WANT_KEY,
    all.map((t) => (t.id === id ? { ...t, deletedByMe: true } : t)),
  );
};

/** @deprecated prefer kk_want_delete */
export const deleteTellForMe = kk_want_delete;

// ── ai_usage / kk_ai_* ─────────────────────────────────────────────────

/** TODO → kk_ai_usage_get (10 / couple / month) */
export const kk_ai_usage_get = async (): Promise<AiUsage> => {
  const q = readJson<{ used: number; limit: number; month: string }>(AI_KEY, {
    used: 3,
    limit: 10,
    month: new Date().toISOString().slice(0, 7),
  });
  const month = new Date().toISOString().slice(0, 7);
  if (q.month !== month) {
    const reset = { used: 0, limit: 10, month };
    writeJson(AI_KEY, reset);
    return { used: 0, limit: 10, remaining: 10 };
  }
  return { used: q.used, limit: q.limit, remaining: Math.max(0, q.limit - q.used) };
};

/** @deprecated prefer kk_ai_usage_get */
export const getAiQuota = kk_ai_usage_get;

/**
 * TODO → kk_ai_consume_and_run
 * Accepts ONLY user-submitted text + memory item fields.
 * Server whitelist enforced; NEVER chat ciphertext.
 */
export const kk_ai_consume_and_run = async (input: {
  text: string;
  memoryItemIds?: string[];
}): Promise<AiExpandResult> => {
  const q = await kk_ai_usage_get();
  if (q.remaining <= 0) throw new Error("AI quota exhausted");
  const next = {
    used: q.used + 1,
    limit: q.limit,
    month: new Date().toISOString().slice(0, 7),
  };
  writeJson(AI_KEY, next);
  const text = input.text.trim();
  return {
    organized: `【整理】\n${text.slice(0, 400)}`,
    plan: `【諗計劃】\n1. 揀一個輕鬆時段一齊做\n2. 準備簡單道具或地點\n3. 事後記低感受放落記憶空間`,
  };
};

/** @deprecated prefer kk_ai_consume_and_run */
export const aiExpand = async (text: string): Promise<AiExpandResult> =>
  kk_ai_consume_and_run({ text });

/** @deprecated */
export const consumeAiQuota = async (): Promise<AiUsage> => {
  await kk_ai_consume_and_run({ text: " " });
  return kk_ai_usage_get();
};

// ── mood / kk_set_daily_mood ───────────────────────────────────────────

/** Local read of today's mood (mock). TODO: read users.mood / mood_updated_at */
export const getMoodForToday = (): MoodId | null => {
  const day = hktMoodDayId();
  const stored = readJson<{ day: string; mood: MoodId } | null>(MOOD_KEY, null);
  if (stored && stored.day === day) return stored.mood;
  return null;
};

/** TODO → kk_set_daily_mood (reuse users.mood / mood_updated_at; HKT 06:00 gate) */
export const kk_set_daily_mood = (mood: MoodId): void => {
  writeJson(MOOD_KEY, { day: hktMoodDayId(), mood });
};

/** @deprecated prefer kk_set_daily_mood */
export const setMoodForToday = kk_set_daily_mood;

// ── optional 你哋嘅日子 (couples.anniversary_iso nullable) ─────────────

export const getOurDay = (): string => readJson<string>(DAY_KEY, "");
export const setOurDay = (iso: string): void => writeJson(DAY_KEY, iso);

export const E2EE_COPY =
  "傾計端對端加密，伺服器讀唔到；記憶空間儲存在伺服器以便雙方共享同提醒；AI 只處理你提交嘅內容。";

export const CHAT_BANNER_48H = "傾計訊息 48 小時後自動刪除";
export const CHAT_BANNER_E2EE = "傾計內容只有你哋兩個睇到";
