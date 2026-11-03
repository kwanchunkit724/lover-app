/**
 * KK adapter — UI → live Supabase kk_* RPCs + RLS tables on us-app.
 * Function/type names mirror backend RPCs so iOS/web/backend stay aligned.
 *
 * Tables: memory_items, want_you_know, want_you_know_reads, ai_usage,
 *   kaomoji_prefs, kaomoji_catalog
 * RPCs: kk_set_daily_mood, kk_memory_*, kk_memory_from_chat, kk_want_*,
 *   kk_ai_consume_and_run, kk_ai_usage_get, kk_kaomoji_prefs_get/set,
 *   kk_purge_expired_messages (optional client; primary is Edge/cron)
 * Reuse: pairing_codes, users.mood / mood_updated_at, couples, messages E2EE
 *
 * Sixth mood locked: 有啲 + U+6530 (UTF-8 e694b0). Never 攤/攠(U+6520)/收/支/撃/擊.
 */

import { createClient } from "@/lib/supabase/client";

export type MemoryCategory = "日常" | "約會" | "計劃" | "其他";

/** Locked sixth mood: 有啲 + U+6530 per Chunkit. Do NOT use 收 (U+6536), 支 (U+652F), or 攠 (U+6520). */
export type MoodId =
  | "開心"
  | "平靜"
  | "有啲攰"
  | "低落"
  | "掛住你"
  | "有啲煩";

const SIXTH_MOOD = ("有啲" + String.fromCodePoint(0x6530)) as MoodId;

export const MOODS: { id: MoodId; kao: string; en: string }[] = [
  { id: "開心", kao: "(ﾉ´ヮ`)ﾉ*:・ﾟ", en: "Happy" },
  { id: "平靜", kao: "(◕‿◕)", en: "Calm" },
  { id: SIXTH_MOOD, kao: "(・_・;)", en: "Meh" },
  { id: "低落", kao: "(´；ω；`)", en: "Low" },
  { id: "掛住你", kao: "(♡˙︶˙♡)", en: "Miss you" },
  { id: "有啲煩", kao: "(￣ヘ￣)", en: "Stressed" },
];

/** Mirrors memory_items row (UI shape). */
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
  /** Present when Gemini Edge is not wired yet (RPC stub). */
  stub?: boolean;
  note?: string;
}

const MOOD_KEY = "kk.cache.daily_mood";
const DAY_KEY = "kk.cache.our_day";

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

const rpcError = (err: { message?: string } | null, fallback: string): Error =>
  new Error(err?.message || fallback);

/** HKT calendar day id after 06:00 HKT gate (matches kk_set_daily_mood). */
export const hktMoodDayId = (now = new Date()): string => {
  const hkt = new Date(now.getTime() + 8 * 60 * 60 * 1000);
  if (hkt.getUTCHours() < 6) hkt.setUTCDate(hkt.getUTCDate() - 1);
  return hkt.toISOString().slice(0, 10);
};

const isMoodId = (v: string | null | undefined): v is MoodId =>
  !!v && MOODS.some((m) => m.id === v);

type MemoryRow = {
  id: string;
  title: string;
  original_text: string;
  category: MemoryCategory;
  note_summary: string;
  source_message_refs: unknown;
  reminder_at: string | null;
  created_at: string;
};

const mapMemory = (row: MemoryRow): MemoryItem => {
  const refs = Array.isArray(row.source_message_refs)
    ? row.source_message_refs
    : [];
  const firstRef =
    typeof refs[0] === "string"
      ? refs[0]
      : refs[0] && typeof refs[0] === "object" && "id" in (refs[0] as object)
        ? String((refs[0] as { id: string }).id)
        : undefined;
  return {
    id: row.id,
    title: row.title,
    originalWords: row.original_text ?? "",
    category: row.category,
    note: row.note_summary || undefined,
    sourceMessage: firstRef,
    reminderAt: row.reminder_at ?? undefined,
    createdAt: row.created_at,
  };
};

const requireUserId = async (): Promise<string> => {
  const supabase = createClient();
  const {
    data: { user },
    error,
  } = await supabase.auth.getUser();
  if (error || !user) throw new Error(error?.message || "not_authenticated");
  return user.id;
};

const getCoupleContext = async (): Promise<{
  userId: string;
  coupleId: string;
  userA: string;
  userB: string;
}> => {
  const supabase = createClient();
  const userId = await requireUserId();
  const { data: couple, error } = await supabase
    .from("couples")
    .select("id, user_a_id, user_b_id")
    .or(`user_a_id.eq.${userId},user_b_id.eq.${userId}`)
    .maybeSingle();
  if (error) throw rpcError(error, "couple_lookup_failed");
  if (!couple) throw new Error("not_paired");
  return {
    userId,
    coupleId: couple.id,
    userA: couple.user_a_id,
    userB: couple.user_b_id,
  };
};

// ── memory_items / kk_memory_* ──────────────────────────────────────────

/** Select memory_items (RLS); no list RPC. */
export const kk_memory_list = async (): Promise<MemoryItem[]> => {
  const supabase = createClient();
  const { data, error } = await supabase
    .from("memory_items")
    .select(
      "id, title, original_text, category, note_summary, source_message_refs, reminder_at, created_at",
    )
    .order("created_at", { ascending: false });
  if (error) throw rpcError(error, "kk_memory_list_failed");
  return ((data ?? []) as MemoryRow[]).map(mapMemory);
};

/** @deprecated prefer kk_memory_list */
export const listMemories = kk_memory_list;

export const kk_memory_create = async (
  input: Omit<MemoryItem, "id" | "createdAt">,
): Promise<MemoryItem> => {
  const supabase = createClient();
  const { data: id, error } = await supabase.rpc("kk_memory_create", {
    p_title: input.title,
    p_original_text: input.originalWords,
    p_category: input.category,
    p_note_summary: input.note ?? "",
    p_source_message_refs: input.sourceMessage
      ? [input.sourceMessage]
      : [],
    p_reminder_at: input.reminderAt ?? null,
  });
  if (error) throw rpcError(error, "kk_memory_create_failed");
  const { data: row, error: fetchErr } = await supabase
    .from("memory_items")
    .select(
      "id, title, original_text, category, note_summary, source_message_refs, reminder_at, created_at",
    )
    .eq("id", id)
    .single();
  if (fetchErr || !row) {
    return {
      ...input,
      id: String(id),
      createdAt: new Date().toISOString(),
    };
  }
  return mapMemory(row as MemoryRow);
};

/** @deprecated prefer kk_memory_create */
export const createMemory = kk_memory_create;

/**
 * Merge selected chat originals into a memory — NO AI quota.
 * Client sends only plaintext excerpts (never ciphertext).
 */
export const kk_memory_from_chat = async (input: {
  title: string;
  originalWords: string;
  category: MemoryCategory;
  note?: string;
}): Promise<MemoryItem> => {
  const supabase = createClient();
  const { data: id, error } = await supabase.rpc("kk_memory_from_chat", {
    p_title: input.title,
    p_original_text: input.originalWords,
    p_category: input.category,
    p_source_message_refs: [],
  });
  if (error) throw rpcError(error, "kk_memory_from_chat_failed");
  if (input.note) {
    await supabase.rpc("kk_memory_update", {
      p_id: id,
      p_note_summary: input.note,
    });
  }
  const { data: row } = await supabase
    .from("memory_items")
    .select(
      "id, title, original_text, category, note_summary, source_message_refs, reminder_at, created_at",
    )
    .eq("id", id)
    .maybeSingle();
  if (row) return mapMemory(row as MemoryRow);
  return {
    id: String(id),
    title: input.title,
    originalWords: input.originalWords,
    category: input.category,
    note: input.note,
    createdAt: new Date().toISOString(),
  };
};

export const kk_memory_update = async (
  id: string,
  patch: Partial<
    Pick<MemoryItem, "title" | "originalWords" | "category" | "note" | "reminderAt">
  > & { clearReminder?: boolean },
): Promise<void> => {
  const supabase = createClient();
  const { error } = await supabase.rpc("kk_memory_update", {
    p_id: id,
    p_title: patch.title ?? null,
    p_original_text: patch.originalWords ?? null,
    p_category: patch.category ?? null,
    p_note_summary: patch.note ?? null,
    p_reminder_at: patch.reminderAt ?? null,
    p_clear_reminder: patch.clearReminder ?? false,
  });
  if (error) throw rpcError(error, "kk_memory_update_failed");
};

export const kk_memory_delete = async (id: string): Promise<void> => {
  const supabase = createClient();
  const { error } = await supabase.rpc("kk_memory_delete", { p_id: id });
  if (error) throw rpcError(error, "kk_memory_delete_failed");
};

/** @deprecated prefer kk_memory_delete */
export const deleteMemory = kk_memory_delete;

// ── want_you_know / kk_want_* ───────────────────────────────────────────

type WantRow = {
  id: string;
  title: string | null;
  body: string;
  deadline_at: string | null;
  remind: boolean;
  author_id: string;
  deleted_by_a: boolean;
  deleted_by_b: boolean;
  created_at: string;
};

export const kk_want_list = async (): Promise<WantYouKnowItem[]> => {
  const { userId, userA, userB } = await getCoupleContext();
  const supabase = createClient();
  const { data, error } = await supabase
    .from("want_you_know")
    .select(
      "id, title, body, deadline_at, remind, author_id, deleted_by_a, deleted_by_b, created_at",
    )
    .order("created_at", { ascending: false });
  if (error) throw rpcError(error, "kk_want_list_failed");
  const rows = (data ?? []) as WantRow[];
  const ids = rows.map((r) => r.id);
  const readsByItem = new Map<string, Set<string>>();
  if (ids.length) {
    const { data: reads, error: readErr } = await supabase
      .from("want_you_know_reads")
      .select("item_id, user_id")
      .in("item_id", ids);
    if (readErr) throw rpcError(readErr, "kk_want_reads_failed");
    for (const r of reads ?? []) {
      const set = readsByItem.get(r.item_id) ?? new Set<string>();
      set.add(r.user_id);
      readsByItem.set(r.item_id, set);
    }
  }
  const iAmA = userId === userA;
  return rows
    .map((row): WantYouKnowItem => {
      const readers = readsByItem.get(row.id) ?? new Set();
      const deletedByMe = iAmA ? row.deleted_by_a : row.deleted_by_b;
      const deletedByPartner = iAmA ? row.deleted_by_b : row.deleted_by_a;
      return {
        id: row.id,
        title: row.title ?? undefined,
        content: row.body,
        deadline: row.deadline_at ?? undefined,
        reminder: row.remind,
        createdBy: row.author_id === userId ? "me" : "partner",
        readByMe: readers.has(userId),
        readByPartner: readers.has(iAmA ? userB : userA),
        deletedByMe,
        deletedByPartner,
        createdAt: row.created_at,
      };
    })
    .filter((t) => !(t.deletedByMe && t.deletedByPartner))
    .filter((t) => !t.deletedByMe);
};

/** @deprecated prefer kk_want_list */
export const listTells = kk_want_list;

export const kk_want_create = async (
  input: Pick<WantYouKnowItem, "title" | "content" | "deadline" | "reminder">,
): Promise<WantYouKnowItem> => {
  const supabase = createClient();
  const { data: id, error } = await supabase.rpc("kk_want_create", {
    p_body: input.content,
    p_title: input.title ?? null,
    p_deadline_at: input.deadline ?? null,
    p_remind: input.reminder ?? false,
  });
  if (error) throw rpcError(error, "kk_want_create_failed");
  // Author auto-read
  await supabase.rpc("kk_want_mark_read", { p_id: id });
  return {
    id: String(id),
    title: input.title,
    content: input.content,
    deadline: input.deadline,
    reminder: input.reminder,
    createdBy: "me",
    readByMe: true,
    readByPartner: false,
    deletedByMe: false,
    deletedByPartner: false,
    createdAt: new Date().toISOString(),
  };
};

/** @deprecated prefer kk_want_create */
export const createTell = kk_want_create;

export const kk_want_mark_read = async (id: string): Promise<void> => {
  const supabase = createClient();
  const { error } = await supabase.rpc("kk_want_mark_read", { p_id: id });
  if (error) throw rpcError(error, "kk_want_mark_read_failed");
};

/** @deprecated prefer kk_want_mark_read */
export const markTellRead = kk_want_mark_read;

/** Soft-delete for me via kk_want_soft_delete. */
export const kk_want_delete = async (id: string): Promise<void> => {
  const supabase = createClient();
  const { error } = await supabase.rpc("kk_want_soft_delete", { p_id: id });
  if (error) throw rpcError(error, "kk_want_soft_delete_failed");
};

/** @deprecated prefer kk_want_delete */
export const deleteTellForMe = kk_want_delete;

// ── ai_usage / kk_ai_* ─────────────────────────────────────────────────

export const kk_ai_usage_get = async (): Promise<AiUsage> => {
  const supabase = createClient();
  const { data, error } = await supabase.rpc("kk_ai_usage_get");
  if (error) {
    // Unpaired / unauthenticated — surface empty quota rather than crash tabs
    const msg = error.message || "";
    if (msg.includes("not_paired") || msg.includes("not_authenticated")) {
      return { used: 0, limit: 10, remaining: 10 };
    }
    throw rpcError(error, "kk_ai_usage_get_failed");
  }
  const row = (data ?? {}) as {
    used?: number;
    cap?: number;
    remaining?: number;
  };
  const used = Number(row.used ?? 0);
  const limit = Number(row.cap ?? 10);
  return {
    used,
    limit,
    remaining: Number(row.remaining ?? Math.max(0, limit - used)),
  };
};

/** @deprecated prefer kk_ai_usage_get */
export const getAiQuota = kk_ai_usage_get;

/**
 * kk_ai_consume_and_run — whitelist user text + memory items only.
 * Gemini Edge may be undeployed: RPC returns stub; UI shows clear copy.
 */
export const kk_ai_consume_and_run = async (input: {
  text: string;
  memoryItemIds?: string[];
}): Promise<AiExpandResult> => {
  const text = input.text.trim();
  if (!text && !(input.memoryItemIds && input.memoryItemIds.length)) {
    throw new Error("empty_ai_input");
  }
  // Client-side reject obvious ciphertext blobs
  if (
    /ciphertext/i.test(text) ||
    /^[A-Za-z0-9+/=]{80,}$/.test(text.replace(/\s/g, ""))
  ) {
    throw new Error("chat_ciphertext_forbidden");
  }
  const supabase = createClient();
  const payload: Record<string, unknown> = { user_text: text };
  if (input.memoryItemIds?.length) payload.memory_ids = input.memoryItemIds;
  const { data, error } = await supabase.rpc("kk_ai_consume_and_run", {
    p_payload: payload,
  });
  if (error) {
    const msg = error.message || "kk_ai_consume_and_run_failed";
    if (msg.includes("ai_quota_exhausted")) throw new Error("AI quota exhausted");
    throw new Error(msg);
  }
  const body = (data ?? {}) as {
    result?: { status?: string; note?: string; organized?: string; plan?: string };
    input?: { user_text?: string };
  };
  const result = body.result ?? {};
  if (result.status === "stub" || !result.organized) {
    const note =
      result.note ||
      "AI 整理服務尚未上線（Gemini Edge stub）。配額已扣；稍後再試或手打計劃。";
    return {
      organized: `【整理 · stub】\n${text.slice(0, 400) || "（無文字）"}`,
      plan: `【諗計劃 · stub】\n${note}\n\n1. 揀一個輕鬆時段一齊做\n2. 準備簡單道具或地點\n3. 事後記低感受放落記憶空間`,
      stub: true,
      note,
    };
  }
  return {
    organized: String(result.organized),
    plan: String(result.plan ?? ""),
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

/** Local cache of today's mood (sync gate for routing). */
export const getMoodForToday = (): MoodId | null => {
  const day = hktMoodDayId();
  const stored = readJson<{ day: string; mood: MoodId } | null>(MOOD_KEY, null);
  if (stored && stored.day === day && isMoodId(stored.mood)) return stored.mood;
  return null;
};

/** Hydrate cache from users.mood / mood_updated_at (HKT day). */
export const refreshMoodFromServer = async (): Promise<MoodId | null> => {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return getMoodForToday();
  const { data, error } = await supabase
    .from("users")
    .select("mood, mood_updated_at")
    .eq("id", user.id)
    .maybeSingle();
  if (error || !data?.mood || !isMoodId(data.mood)) return getMoodForToday();
  if (!data.mood_updated_at) return getMoodForToday();
  const updated = new Date(data.mood_updated_at);
  const day = hktMoodDayId(updated);
  if (day !== hktMoodDayId()) return null;
  writeJson(MOOD_KEY, { day, mood: data.mood });
  return data.mood;
};

/** kk_set_daily_mood — writes users.mood; caches locally for sync gates. */
export const kk_set_daily_mood = async (mood: MoodId): Promise<void> => {
  if (!isMoodId(mood)) throw new Error("invalid_mood");
  const supabase = createClient();
  const { error } = await supabase.rpc("kk_set_daily_mood", {
    p_mood: mood,
    p_hkt_date: hktMoodDayId(),
  });
  if (error) throw rpcError(error, "kk_set_daily_mood_failed");
  writeJson(MOOD_KEY, { day: hktMoodDayId(), mood });
};

/** @deprecated prefer kk_set_daily_mood */
export const setMoodForToday = kk_set_daily_mood;

// ── optional 你哋嘅日子 (users.anniversary_iso for now) ─────────────────

export const getOurDay = (): string => readJson<string>(DAY_KEY, "");
export const setOurDay = (iso: string): void => writeJson(DAY_KEY, iso);

/** Optional client trigger; primary purge is backend Edge/cron. */
export const kk_purge_expired_messages = async (): Promise<{
  deleted_messages: number;
  memory_rows_touched: number;
}> => {
  const supabase = createClient();
  const { data, error } = await supabase.rpc("kk_purge_expired_messages");
  if (error) throw rpcError(error, "kk_purge_expired_messages_failed");
  const row = (data ?? {}) as {
    deleted_messages?: number;
    memory_rows_touched?: number;
  };
  return {
    deleted_messages: Number(row.deleted_messages ?? 0),
    memory_rows_touched: Number(row.memory_rows_touched ?? 0),
  };
};

export const E2EE_COPY =
  "傾計端對端加密，伺服器讀唔到；記憶空間儲存在伺服器以便雙方共享同提醒；AI 只處理你提交嘅內容。";

export const CHAT_BANNER_48H = "傾計訊息 48 小時後自動刪除";
export const CHAT_BANNER_E2EE = "傾計內容只有你哋兩個睇到";
