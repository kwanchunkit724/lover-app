// AES-GCM-256 seal/open for ChatPayload using the derived chatKey.
//
// Wire format MUST match iOS CryptoKit AES.GCM.SealedBox.combined and
// Android javax.crypto AES/GCM/NoPadding output:
//
//   combined = [12-byte nonce | ciphertext | 16-byte tag]
//
// Plaintext = UTF-8 JSON of ChatPayload (ISO-8601 dates).
// Result is base64 (standard, with padding) — stored in messages.ciphertext_b64.

import type { ChatPayload } from "./payload";

// seal/open are generic over the JSON-serializable payload so the same
// crypto primitives back chat messages AND anniversaries AND entries.
// Default type param is ChatPayload for the chat call sites that don't
// pass an explicit T.

const NONCE_LEN = 12;
const TAG_LEN = 16;

/** Copies a Uint8Array into a fresh ArrayBuffer-backed view so it satisfies
 *  WebCrypto's `BufferSource` parameter type under strict TS settings. */
const toAB = (u: Uint8Array): ArrayBuffer => {
  const ab = new ArrayBuffer(u.byteLength);
  new Uint8Array(ab).set(u);
  return ab;
};

const b64encode = (bytes: Uint8Array): string => {
  let s = "";
  for (let i = 0; i < bytes.length; i++) s += String.fromCharCode(bytes[i]);
  return btoa(s);
};

const b64decode = (s: string): Uint8Array => {
  const raw = atob(s);
  const bytes = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) bytes[i] = raw.charCodeAt(i);
  return bytes;
};

const importKey = async (raw: Uint8Array): Promise<CryptoKey> => {
  if (raw.length !== 32) throw new Error(`seal: bad key length ${raw.length}`);
  return crypto.subtle.importKey(
    "raw",
    toAB(raw),
    { name: "AES-GCM" },
    false,
    ["encrypt", "decrypt"],
  );
};

/**
 * Encrypts arbitrary bytes with the couple's chatKey.
 *
 * Output layout: [12-byte nonce | ciphertext | 16-byte tag] (a single
 * Uint8Array, no base64 wrapping). Used for media file uploads —
 * Supabase Storage stores raw bytes, not base64 strings.
 */
export const sealBytes = async (
  plaintext: Uint8Array,
  chatKey: Uint8Array,
): Promise<Uint8Array> => {
  const key = await importKey(chatKey);
  const nonce = crypto.getRandomValues(new Uint8Array(NONCE_LEN));
  const cipherWithTag = new Uint8Array(
    await crypto.subtle.encrypt(
      { name: "AES-GCM", iv: toAB(nonce), tagLength: TAG_LEN * 8 },
      key,
      toAB(plaintext),
    ),
  );
  const combined = new Uint8Array(NONCE_LEN + cipherWithTag.length);
  combined.set(nonce, 0);
  combined.set(cipherWithTag, NONCE_LEN);
  return combined;
};

/**
 * Decrypts a sealed bytes blob produced by `sealBytes`. Throws on
 * tamper / wrong key.
 */
export const openBytes = async (
  combined: Uint8Array,
  chatKey: Uint8Array,
): Promise<Uint8Array> => {
  const key = await importKey(chatKey);
  if (combined.length < NONCE_LEN + TAG_LEN) {
    throw new Error(`openBytes: combined too short (${combined.length})`);
  }
  const nonce = combined.subarray(0, NONCE_LEN);
  const cipherWithTag = combined.subarray(NONCE_LEN);
  const plaintextBuf = await crypto.subtle.decrypt(
    { name: "AES-GCM", iv: toAB(nonce), tagLength: TAG_LEN * 8 },
    key,
    toAB(cipherWithTag),
  );
  return new Uint8Array(plaintextBuf);
};

/**
 * Encrypts a JSON-serializable payload with the couple's chatKey.
 *
 * Output: base64 of [12-byte nonce | ciphertext | 16-byte tag].
 * Drop into messages.ciphertext_b64 / anniversaries.ciphertext_b64 / etc.
 */
export const seal = async <T = ChatPayload>(payload: T, chatKey: Uint8Array): Promise<string> => {
  const plaintext = new TextEncoder().encode(JSON.stringify(payload));
  const combined = await sealBytes(plaintext, chatKey);
  return b64encode(combined);
};

/**
 * Decrypts a base64 SealedBox.combined into a ChatPayload.
 * Throws on tamper / wrong key / bad JSON — caller should render a
 * "(decryption failed)" placeholder rather than dropping the row.
 */
export const open = async <T = ChatPayload>(combinedB64: string, chatKey: Uint8Array): Promise<T> => {
  const plaintext = await openBytes(b64decode(combinedB64), chatKey);
  const json = new TextDecoder().decode(plaintext);
  return JSON.parse(json) as T;
};
