// Anniversaries service — same E2EE pattern as messages.
// Plaintext = AnniversaryPayload JSON, sealed with the same chatKey.

import type { SupabaseClient, RealtimeChannel } from "@supabase/supabase-js";
import dayjs from "dayjs";
import { seal, open } from "@/lib/crypto/seal";

export interface AnniversaryPayload {
  v: 1;
  title: string;
  /** "yyyy-MM-dd" date string */
  baseDateISO: string;
  recur: "yearly" | "monthly";
  kaomoji?: string;
  emoji?: string;
  subtitle?: string;
}

export interface AnniversaryRow {
  id: string;
  couple_id: string;
  sender_id: string;
  ciphertext_b64: string;
  created_at: string;
}

export interface DecryptedAnniversary {
  id: string;
  senderId: string;
  payload: AnniversaryPayload | null;
  daysUntilNext: number | null;
}

const computeDaysUntilNext = (
  baseDateISO: string,
  recur: "yearly" | "monthly",
): number | null => {
  const base = dayjs(baseDateISO);
  if (!base.isValid()) return null;
  const today = dayjs().startOf("day");
  let next = base;
  if (recur === "yearly") {
    next = base.year(today.year());
    if (next.isBefore(today)) next = next.add(1, "year");
  } else {
    next = base.year(today.year()).month(today.month());
    if (next.isBefore(today)) next = next.add(1, "month");
  }
  return next.diff(today, "day");
};

const decrypt = async (
  row: AnniversaryRow,
  chatKey: Uint8Array,
): Promise<DecryptedAnniversary> => {
  try {
    const payload = await open<AnniversaryPayload>(row.ciphertext_b64, chatKey);
    return {
      id: row.id,
      senderId: row.sender_id,
      payload,
      daysUntilNext: computeDaysUntilNext(payload.baseDateISO, payload.recur),
    };
  } catch {
    return { id: row.id, senderId: row.sender_id, payload: null, daysUntilNext: null };
  }
};

export const fetchAnniversaries = async (
  supabase: SupabaseClient,
  coupleId: string,
  chatKey: Uint8Array,
): Promise<DecryptedAnniversary[]> => {
  const { data, error } = await supabase
    .from("anniversaries")
    .select("*")
    .eq("couple_id", coupleId)
    .order("created_at", { ascending: true });
  if (error) throw error;
  return Promise.all((data as AnniversaryRow[]).map((r) => decrypt(r, chatKey)));
};

export const addAnniversary = async (
  supabase: SupabaseClient,
  coupleId: string,
  senderId: string,
  chatKey: Uint8Array,
  payload: Omit<AnniversaryPayload, "v">,
): Promise<void> => {
  const full: AnniversaryPayload = { v: 1, ...payload };
  const ciphertext = await seal<AnniversaryPayload>(full, chatKey);
  const { error } = await supabase.from("anniversaries").insert({
    couple_id: coupleId,
    sender_id: senderId,
    ciphertext_b64: ciphertext,
  });
  if (error) throw error;
};

export const deleteAnniversary = async (
  supabase: SupabaseClient,
  id: string,
): Promise<void> => {
  const { error } = await supabase.from("anniversaries").delete().eq("id", id);
  if (error) throw error;
};

export const subscribeAnniversaries = (
  supabase: SupabaseClient,
  coupleId: string,
  chatKey: Uint8Array,
  onAdd: (a: DecryptedAnniversary) => void,
  onDelete: (id: string) => void,
): RealtimeChannel => {
  return supabase
    .channel(`anniversaries:${coupleId}`)
    .on(
      "postgres_changes",
      {
        event: "INSERT",
        schema: "public",
        table: "anniversaries",
        filter: `couple_id=eq.${coupleId}`,
      },
      async (payload) => {
        const dec = await decrypt(payload.new as AnniversaryRow, chatKey);
        onAdd(dec);
      },
    )
    .on(
      "postgres_changes",
      {
        event: "DELETE",
        schema: "public",
        table: "anniversaries",
        filter: `couple_id=eq.${coupleId}`,
      },
      (payload) => onDelete((payload.old as AnniversaryRow).id),
    )
    .subscribe();
};
