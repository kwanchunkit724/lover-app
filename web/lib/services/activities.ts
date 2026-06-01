// Activities catalog — date cards + play history.
//
// DATE_CARDS holds all 120 HK-rooted cards, extracted directly from
// ios/LoverApp/Core/Catalogs.swift via scripts/extract-cards.mjs. Keep
// in sync with the iOS source — re-run the extractor whenever the iOS
// catalog grows.
//
// History is sealed-JSON in public.play_history table — same chatKey
// as messages/anniversaries/entries.

import type { SupabaseClient } from "@supabase/supabase-js";
import { open, seal } from "@/lib/crypto/seal";
import dateCardsJson from "./date-cards.json";

export interface DateCard {
  id: number;
  title: string;
  detail: string;
  mood: string;
  kaomoji: string;
  cost: "$" | "$$" | "$$$";
}

export const DATE_CARDS: DateCard[] = dateCardsJson as DateCard[];

export interface PlayHistoryPayload {
  v: 1;
  kind: "date_card";
  cardId: number;
  doneAtISO: string;
  reflection?: string;
}

export interface PlayHistoryRow {
  id: string;
  couple_id: string;
  sender_id: string;
  ciphertext_b64: string;
  created_at: string;
}

export interface DecryptedHistory {
  id: string;
  senderId: string;
  createdAt: string;
  payload: PlayHistoryPayload | null;
}

const decrypt = async (row: PlayHistoryRow, key: Uint8Array): Promise<DecryptedHistory> => {
  try {
    const payload = await open<PlayHistoryPayload>(row.ciphertext_b64, key);
    return { id: row.id, senderId: row.sender_id, createdAt: row.created_at, payload };
  } catch {
    return { id: row.id, senderId: row.sender_id, createdAt: row.created_at, payload: null };
  }
};

export const fetchHistory = async (
  supabase: SupabaseClient,
  coupleId: string,
  chatKey: Uint8Array,
): Promise<DecryptedHistory[]> => {
  const { data, error } = await supabase
    .from("play_history")
    .select("*")
    .eq("couple_id", coupleId)
    .order("created_at", { ascending: false })
    .limit(100);
  if (error) throw error;
  return Promise.all((data as PlayHistoryRow[]).map((r) => decrypt(r, chatKey)));
};

export const markCardDone = async (
  supabase: SupabaseClient,
  coupleId: string,
  senderId: string,
  chatKey: Uint8Array,
  cardId: number,
  reflection?: string,
): Promise<void> => {
  const payload: PlayHistoryPayload = {
    v: 1,
    kind: "date_card",
    cardId,
    doneAtISO: new Date().toISOString(),
    reflection,
  };
  const ciphertext = await seal<PlayHistoryPayload>(payload, chatKey);
  const { error } = await supabase.from("play_history").insert({
    couple_id: coupleId,
    sender_id: senderId,
    ciphertext_b64: ciphertext,
  });
  if (error) throw error;
};
