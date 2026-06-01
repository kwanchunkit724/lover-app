// Chat service — handles fetch, send, and Realtime subscribe.
//
// Mirrors ios/LoverApp/Services/ChatService.swift behaviour:
//
//   fetchInitial(): SELECT order by created_at DESC limit 500, reverse for UI
//                   (newest-500-window, avoids losing latest after 500 total)
//   subscribe():    Supabase Realtime postgres_changes on messages table,
//                   filtered by couple_id
//   send(text):     seal(ChatPayload) → insert row
//
// Decryption errors do NOT drop the row — caller renders a "(decryption
// failed)" placeholder via `decrypted=null` so the user can see something
// happened and report it.

import type { SupabaseClient, RealtimeChannel } from "@supabase/supabase-js";
import { open, seal } from "@/lib/crypto/seal";
import { textPayload, photoPayload, type ChatPayload } from "@/lib/crypto/payload";
import { encryptAndUpload } from "@/lib/services/media";

export interface MessageRow {
  id: string;
  couple_id: string;
  sender_id: string;
  ciphertext_b64: string;
  created_at: string;
}

export interface DecryptedMessage {
  id: string;
  senderId: string;
  createdAt: string;
  /** null when decrypt failed — render a placeholder bubble. */
  payload: ChatPayload | null;
}

const MAX_FETCH = 500;

const decryptRow = async (row: MessageRow, chatKey: Uint8Array): Promise<DecryptedMessage> => {
  try {
    const payload = await open(row.ciphertext_b64, chatKey);
    return { id: row.id, senderId: row.sender_id, createdAt: row.created_at, payload };
  } catch {
    return { id: row.id, senderId: row.sender_id, createdAt: row.created_at, payload: null };
  }
};

export const fetchInitial = async (
  supabase: SupabaseClient,
  coupleId: string,
  chatKey: Uint8Array,
): Promise<DecryptedMessage[]> => {
  // Order DESC + limit = newest N. Reverse for UI (oldest at top).
  const { data, error } = await supabase
    .from("messages")
    .select("*")
    .eq("couple_id", coupleId)
    .order("created_at", { ascending: false })
    .limit(MAX_FETCH);
  if (error) throw error;
  const rows = (data as MessageRow[]).reverse();
  return Promise.all(rows.map((r) => decryptRow(r, chatKey)));
};

export const sendText = async (
  supabase: SupabaseClient,
  coupleId: string,
  senderId: string,
  chatKey: Uint8Array,
  text: string,
): Promise<void> => {
  const ciphertext = await seal(textPayload(text), chatKey);
  const { error } = await supabase.from("messages").insert({
    couple_id: coupleId,
    sender_id: senderId,
    ciphertext_b64: ciphertext,
  });
  if (error) throw error;
};

export const sendPhoto = async (
  supabase: SupabaseClient,
  coupleId: string,
  senderId: string,
  chatKey: Uint8Array,
  bytes: Uint8Array,
): Promise<void> => {
  // Encrypt + upload the image, then seal a ChatPayload that references it.
  const mediaHandle = await encryptAndUpload(supabase, coupleId, chatKey, bytes);
  const ciphertext = await seal(photoPayload(mediaHandle), chatKey);
  const { error } = await supabase.from("messages").insert({
    couple_id: coupleId,
    sender_id: senderId,
    ciphertext_b64: ciphertext,
  });
  if (error) throw error;
};

export const subscribe = (
  supabase: SupabaseClient,
  coupleId: string,
  chatKey: Uint8Array,
  onMessage: (msg: DecryptedMessage) => void,
  /** Fired every time the channel reaches SUBSCRIBED (initial connect AND
   *  reconnects). Use it to (re)fetch and close the gap where an INSERT
   *  lands before the realtime handshake completes — otherwise that message
   *  is lost forever on this client. */
  onSubscribed?: () => void,
): RealtimeChannel => {
  const channel = supabase
    .channel(`messages:${coupleId}`)
    .on(
      "postgres_changes",
      {
        event: "INSERT",
        schema: "public",
        table: "messages",
        filter: `couple_id=eq.${coupleId}`,
      },
      async (payload) => {
        try {
          const row = payload.new as MessageRow;
          const decrypted = await decryptRow(row, chatKey);
          onMessage(decrypted);
        } catch (e) {
          console.error("realtime message handler failed", e);
        }
      },
    )
    .subscribe((status) => {
      if (status === "SUBSCRIBED") onSubscribed?.();
    });
  return channel;
};
