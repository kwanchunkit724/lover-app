// ChatPayload — wire-format envelope shared with iOS + Android.
//
// CRITICAL: Field names and Kind enum values are part of the wire format.
// Renaming any string here will break decryption on iOS/Android clients
// without a coordinated migration.
//
// Source of truth: ios/LoverApp/Services/CryptoService.swift (ChatPayload).

export type ChatKind = "text" | "kaomoji" | "photo" | "voice" | "video";

export interface ChatPayload {
  v: 1;
  kind: ChatKind;
  /** For text/kaomoji: the message body. For voice/video iOS reuses this
   *  same field to carry the duration as a "0:NN" string on the wire — there
   *  is NO separate duration key in the cross-platform ChatPayload. */
  text?: string;
  /** Supabase Storage path for photo/voice/video. */
  mediaHandle?: string;
  /** ISO-8601 timestamp. */
  sentAt: string;
}

export const textPayload = (t: string): ChatPayload => ({
  v: 1,
  kind: "text",
  text: t,
  sentAt: new Date().toISOString(),
});

export const photoPayload = (mediaHandle: string): ChatPayload => ({
  v: 1,
  kind: "photo",
  mediaHandle,
  sentAt: new Date().toISOString(),
});

// iOS carries video/voice duration inside `text` as "0:NN" (Swift:
// String(format: "0:%02d", durationSec)) and reconstructs it via
// parseVoiceDuration. Match that exact encoding so cross-platform reads
// show the right length instead of "0:00".
export const videoPayload = (mediaHandle: string, durationSec: number): ChatPayload => ({
  v: 1,
  kind: "video",
  mediaHandle,
  text: `0:${String(durationSec).padStart(2, "0")}`,
  sentAt: new Date().toISOString(),
});
