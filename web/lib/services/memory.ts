// Memory / entries service. Mirrors iOS EntryService — sealed JSON
// payloads in public.entries with the same chatKey.
//
// Web v1 surfaces a simplified entry: title + date + tag + notes.
// Full iOS field surface is supported in the payload type so cross-platform
// reads still decode cleanly.

import type { SupabaseClient, RealtimeChannel } from "@supabase/supabase-js";
import { open, seal } from "@/lib/crypto/seal";

export type EntryTag =
  | "date" | "anniversary" | "trip" | "meal" | "movie"
  | "show" | "shopping" | "home" | "work" | "other";

export interface EntryPayload {
  v: 1;
  title: string;
  /** "yyyy-MM-dd" */
  dateISO: string;
  /** "HH:mm" */
  time?: string;
  location?: string;
  proposedBy: string;
  who: "both" | "mine" | "theirs";
  tag: EntryTag;
  isSpecial: boolean;
  notes?: string;
  kaomoji?: string;
  photoCount?: number;
  voiceCount?: number;
  messageCount?: number;
}

export interface EntryRow {
  id: string;
  couple_id: string;
  sender_id: string;
  ciphertext_b64: string;
  created_at: string;
}

export interface DecryptedEntry {
  id: string;
  senderId: string;
  createdAt: string;
  payload: EntryPayload | null;
}

const decrypt = async (row: EntryRow, key: Uint8Array): Promise<DecryptedEntry> => {
  try {
    const payload = await open<EntryPayload>(row.ciphertext_b64, key);
    return { id: row.id, senderId: row.sender_id, createdAt: row.created_at, payload };
  } catch {
    return { id: row.id, senderId: row.sender_id, createdAt: row.created_at, payload: null };
  }
};

export const fetchEntries = async (
  supabase: SupabaseClient,
  coupleId: string,
  chatKey: Uint8Array,
): Promise<DecryptedEntry[]> => {
  const { data, error } = await supabase
    .from("entries")
    .select("*")
    .eq("couple_id", coupleId)
    .order("created_at", { ascending: false });
  if (error) throw error;
  return Promise.all((data as EntryRow[]).map((r) => decrypt(r, chatKey)));
};

export const addEntry = async (
  supabase: SupabaseClient,
  coupleId: string,
  senderId: string,
  chatKey: Uint8Array,
  payload: Omit<EntryPayload, "v">,
): Promise<void> => {
  const full: EntryPayload = { v: 1, ...payload };
  const ciphertext = await seal<EntryPayload>(full, chatKey);
  const { error } = await supabase.from("entries").insert({
    couple_id: coupleId,
    sender_id: senderId,
    ciphertext_b64: ciphertext,
  });
  if (error) throw error;
};

export const deleteEntry = async (supabase: SupabaseClient, id: string) => {
  const { error } = await supabase.from("entries").delete().eq("id", id);
  if (error) throw error;
};

export const subscribeEntries = (
  supabase: SupabaseClient,
  coupleId: string,
  chatKey: Uint8Array,
  onAdd: (e: DecryptedEntry) => void,
  onDelete: (id: string) => void,
): RealtimeChannel =>
  supabase
    .channel(`entries:${coupleId}`)
    .on(
      "postgres_changes",
      {
        event: "INSERT",
        schema: "public",
        table: "entries",
        filter: `couple_id=eq.${coupleId}`,
      },
      async (p) => onAdd(await decrypt(p.new as EntryRow, chatKey)),
    )
    .on(
      "postgres_changes",
      {
        event: "DELETE",
        schema: "public",
        table: "entries",
        filter: `couple_id=eq.${coupleId}`,
      },
      (p) => onDelete((p.old as EntryRow).id),
    )
    .subscribe();
