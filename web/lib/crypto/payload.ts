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
  text?: string;
  /** Supabase Storage path for photo/voice/video. */
  mediaHandle?: string;
  /** Duration in seconds — used for voice + video. Field name kept
   *  for cross-platform compat (iOS/Android both name it `voiceDurationSec`). */
  voiceDurationSec?: number;
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

export const videoPayload = (mediaHandle: string, durationSec: number): ChatPayload => ({
  v: 1,
  kind: "video",
  mediaHandle,
  voiceDurationSec: durationSec,
  sentAt: new Date().toISOString(),
});
