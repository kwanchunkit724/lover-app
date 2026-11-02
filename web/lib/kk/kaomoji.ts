/** Kaomoji catalogue + preferences (localStorage; cloud sync TODO). */

export type StylePack = "classic" | "nihon" | "exaggerate" | "mix";

export const STYLE_PACK_LABELS: Record<StylePack, string> = {
  classic: "經典",
  nihon: "日系",
  exaggerate: "誇張",
  mix: "混合",
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
  // TODO: kaomoji prefs cloud sync
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
};

export const getStylePack = (): StylePack => loadPrefs().stylePack || "classic";

export const setStylePack = (id: StylePack) => {
  const prefs = loadPrefs();
  prefs.stylePack = id;
  savePrefs(prefs);
};

export const filteredCategories = (catalogue: KaoCatalogue): KaoCategory[] => {
  const ids = STYLE_PACK_FILTER[getStylePack()];
  if (!ids) return catalogue.categories.slice();
  return catalogue.categories.filter((c) => ids.includes(c.id));
};

let cache: KaoCatalogue | null = null;

export const loadCatalogue = async (): Promise<KaoCatalogue> => {
  if (cache) return cache;
  const res = await fetch("/data/kaomoji.json");
  cache = (await res.json()) as KaoCatalogue;
  return cache;
};

/** TODO → kk_kaomoji_prefs_get (currently localStorage via loadPrefs) */
export const kk_kaomoji_prefs_get = loadPrefs;

/** TODO → kk_kaomoji_prefs_set */
export const kk_kaomoji_prefs_set = savePrefs;
