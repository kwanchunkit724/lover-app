/** Kaomoji catalogue + preferences (localStorage cache + kk_kaomoji_prefs_* sync). */

import { createClient } from "@/lib/supabase/client";

export type StylePack = "classic" | "nihon" | "exaggerate" | "mix";

export const STYLE_PACK_LABELS: Record<StylePack, string> = {
  classic: "經典",
  nihon: "日系",
  exaggerate: "誇張",
  mix: "混合",
};

const STYLE_PACK_TO_RPC: Record<StylePack, string> = {
  classic: "經典",
  nihon: "日系",
  exaggerate: "誇張",
  mix: "混合",
};

const STYLE_PACK_FROM_RPC: Record<string, StylePack> = {
  經典: "classic",
  日系: "nihon",
  誇張: "exaggerate",
  混合: "mix",
  classic: "classic",
  nihon: "nihon",
  exaggerate: "exaggerate",
  mix: "mix",
};

const STYLE_PACK_FILTER: Record<StylePack, string[] | null> = {
  classic: null,
  nihon: ["love", "happy", "sleep", "food"],
  exaggerate: ["silly", "surprise", "dance", "sad"],
  mix: null,
};

export interface KaoCategory {
  id: string;
  label_zh: string;
  label_en?: string;
  label_ja?: string;
  entries: string[];
}

export interface KaoCatalogue {
  version: number;
  quick_react: string[];
  categories: KaoCategory[];
}

const PREF_KEY = "kkKaomojiPrefs";
const RECENT_KEY = "kkKaomojiRecent";

export interface KaoPrefs {
  quickReact?: string[];
  stylePack?: StylePack;
}

export const loadPrefs = (): KaoPrefs => {
  if (typeof window === "undefined") return {};
  try {
    return JSON.parse(localStorage.getItem(PREF_KEY) || "{}") as KaoPrefs;
  } catch {
    return {};
  }
};

export const savePrefs = (p: KaoPrefs) => {
  if (typeof window === "undefined") return;
  localStorage.setItem(PREF_KEY, JSON.stringify(p));
};

export const getRecent = (): string[] => {
  if (typeof window === "undefined") return [];
  try {
    return JSON.parse(localStorage.getItem(RECENT_KEY) || "[]") as string[];
  } catch {
    return [];
  }
};

export const pushRecent = (k: string): string[] => {
  const r = getRecent().filter((x) => x !== k);
  r.unshift(k);
  const next = r.slice(0, 18);
  localStorage.setItem(RECENT_KEY, JSON.stringify(next));
  return next;
};

export const clearRecent = () => localStorage.removeItem(RECENT_KEY);

export const getQuickReact = (catalogue: KaoCatalogue | null): string[] => {
  const prefs = loadPrefs();
  const base =
    prefs.quickReact && prefs.quickReact.length
      ? prefs.quickReact
      : catalogue?.quick_react ?? [];
  const out = base.slice(0, 6);
  while (out.length < 6) out.push("");
  return out;
};

export const setQuickReact = (arr: string[]) => {
  const prefs = loadPrefs();
  prefs.quickReact = arr.slice(0, 6).map((x) => x || "");
  savePrefs(prefs);
  void kk_kaomoji_prefs_set(prefs).catch(() => {
    /* offline / unpaired — local cache kept */
  });
};

export const getStylePack = (): StylePack => loadPrefs().stylePack || "classic";

export const setStylePack = (id: StylePack) => {
  const prefs = loadPrefs();
  prefs.stylePack = id;
  savePrefs(prefs);
  void kk_kaomoji_prefs_set(prefs).catch(() => {
    /* offline / unpaired — local cache kept */
  });
};

export const filteredCategories = (catalogue: KaoCatalogue): KaoCategory[] => {
  const ids = STYLE_PACK_FILTER[getStylePack()];
  if (!ids) return catalogue.categories.slice();
  return catalogue.categories.filter((c) => ids.includes(c.id));
};

let cache: KaoCatalogue | null = null;

export const loadCatalogue = async (): Promise<KaoCatalogue> => {
  if (cache) return cache;
  // Prefer cloud catalog when readable; fall back to static asset
  try {
    const supabase = createClient();
    const { data, error } = await supabase
      .from("kaomoji_catalog")
      .select("payload")
      .eq("id", "v3")
      .maybeSingle();
    if (!error && data?.payload) {
      cache = data.payload as KaoCatalogue;
      // Enforce sleep label lock
      for (const c of cache.categories) {
        if (c.id === "sleep") c.label_zh = "睡";
      }
      return cache;
    }
  } catch {
    /* fall through */
  }
  const res = await fetch("/data/kaomoji.json");
  cache = (await res.json()) as KaoCatalogue;
  for (const c of cache.categories) {
    if (c.id === "sleep") c.label_zh = "睡";
  }
  return cache;
};

/** Cloud sync get — merges into localStorage cache. */
export const kk_kaomoji_prefs_get = async (): Promise<KaoPrefs> => {
  const local = loadPrefs();
  try {
    const supabase = createClient();
    const { data, error } = await supabase.rpc("kk_kaomoji_prefs_get");
    if (error) return local;
    const row = (data ?? {}) as {
      quick_react?: string[] | unknown;
      style_pack?: string;
      exists?: boolean;
    };
    if (!row.exists) return local;
    const quick = Array.isArray(row.quick_react)
      ? (row.quick_react as string[])
      : local.quickReact;
    const style =
      (row.style_pack && STYLE_PACK_FROM_RPC[row.style_pack]) ||
      local.stylePack ||
      "classic";
    const merged: KaoPrefs = { quickReact: quick, stylePack: style };
    savePrefs(merged);
    return merged;
  } catch {
    return local;
  }
};

/** Cloud sync set — localStorage remains cache/fallback. */
export const kk_kaomoji_prefs_set = async (p: KaoPrefs): Promise<void> => {
  savePrefs(p);
  const supabase = createClient();
  const { error } = await supabase.rpc("kk_kaomoji_prefs_set", {
    p_quick_react: (p.quickReact ?? []).filter(Boolean).slice(0, 6),
    p_style_pack: STYLE_PACK_TO_RPC[p.stylePack || "classic"],
  });
  if (error) throw error;
};
