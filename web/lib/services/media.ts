// Media service — encrypts file bytes with chatKey, uploads to the
// chat-media Supabase Storage bucket, returns the path to embed as
// ChatPayload.mediaHandle.
//
// Wire format must match iOS MediaService.swift:
//
//   Object path:    "couple-<lowercase couple uuid>/<random uuid>.bin"
//   Object payload: AES-GCM SealedBox.combined of the original file bytes
//                   (NOT JSON; raw nonce ‖ cipher ‖ tag)
//
// Bucket "chat-media" is private; RLS policies (migration 0006) restrict
// SELECT/INSERT to objects whose first path segment matches a couple the
// caller belongs to. The bucket exists from day 1 and is shared across
// iOS / Android / web — nothing to provision.

import type { SupabaseClient } from "@supabase/supabase-js";
import { sealBytes, openBytes } from "@/lib/crypto/seal";

const BUCKET = "chat-media";

const randomUuid = (): string => {
  // crypto.randomUUID is available in modern browsers + Node 19+.
  return crypto.randomUUID();
};

export const encryptAndUpload = async (
  supabase: SupabaseClient,
  coupleId: string,
  chatKey: Uint8Array,
  data: Uint8Array,
): Promise<string> => {
  const sealed = await sealBytes(data, chatKey);
  const path = `couple-${coupleId.toLowerCase()}/${randomUuid().toLowerCase()}.bin`;
  // supabase-js typings want ArrayBuffer / Blob / File. Wrap in a Blob —
  // works in the browser + Node fetch.
  const blob = new Blob([new Uint8Array(sealed)], { type: "application/octet-stream" });
  const { error } = await supabase.storage.from(BUCKET).upload(path, blob, {
    contentType: "application/octet-stream",
    upsert: false,
  });
  if (error) throw error;
  return path;
};

export const downloadAndDecrypt = async (
  supabase: SupabaseClient,
  chatKey: Uint8Array,
  path: string,
): Promise<Uint8Array> => {
  const { data, error } = await supabase.storage.from(BUCKET).download(path);
  if (error) throw error;
  if (!data) throw new Error("downloadAndDecrypt: no data");
  const buf = new Uint8Array(await data.arrayBuffer());
  return openBytes(buf, chatKey);
};

/**
 * Convenience: turns decrypted bytes into a blob URL the browser can
 * render in <img src>. Caller must URL.revokeObjectURL() when done to
 * free memory.
 */
export const bytesToBlobUrl = (bytes: Uint8Array, mimeType = "image/jpeg"): string => {
  const blob = new Blob([new Uint8Array(bytes)], { type: mimeType });
  return URL.createObjectURL(blob);
};

/** Detects MIME type from common magic bytes. Falls back to image/jpeg. */
export const sniffMime = (bytes: Uint8Array): string => {
  if (bytes.length < 8) return "image/jpeg";
  // PNG: 89 50 4E 47 0D 0A 1A 0A
  if (bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e && bytes[3] === 0x47) {
    return "image/png";
  }
  // JPEG: FF D8 FF
  if (bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return "image/jpeg";
  // GIF: 47 49 46 38
  if (bytes[0] === 0x47 && bytes[1] === 0x49 && bytes[2] === 0x46 && bytes[3] === 0x38) {
    return "image/gif";
  }
  // WebP: 52 49 46 46 ... 57 45 42 50
  if (bytes[0] === 0x52 && bytes[1] === 0x49 && bytes[2] === 0x46 && bytes[3] === 0x46) {
    return "image/webp";
  }
  return "image/jpeg";
};
