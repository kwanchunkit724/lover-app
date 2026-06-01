// X25519 keypair management for the web client.
//
// Mirrors iOS KeyManager + Android KeyManager — must produce compatible
// public keys. Private key is the 32-byte raw X25519 scalar (base64
// encoded for localStorage). Public key uploaded to users.public_key as
// base64 of the 32-byte u-coordinate.
//
// Storage: localStorage key `us.crypto.priv.v1`. v1 marker reserved for
// future migration (e.g. wrap with PIN-derived key).

import { x25519 } from "@noble/curves/ed25519.js";

const PRIV_KEY_STORAGE = "us.crypto.priv.v1";
const PUB_KEY_STORAGE = "us.crypto.pub.v1";

export interface KeyPair {
  /** 32-byte X25519 private scalar. */
  privateKey: Uint8Array;
  /** 32-byte X25519 public u-coordinate. */
  publicKey: Uint8Array;
}

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

const isBrowser = () => typeof window !== "undefined" && typeof localStorage !== "undefined";

export const generateKeyPair = (): KeyPair => {
  const privateKey = x25519.utils.randomSecretKey();
  const publicKey = x25519.getPublicKey(privateKey);
  return { privateKey, publicKey };
};

/** Loads cached keypair from localStorage. Returns null if absent. */
export const loadKeyPair = (): KeyPair | null => {
  if (!isBrowser()) return null;
  const privB64 = localStorage.getItem(PRIV_KEY_STORAGE);
  const pubB64 = localStorage.getItem(PUB_KEY_STORAGE);
  if (!privB64 || !pubB64) return null;
  try {
    return {
      privateKey: b64decode(privB64),
      publicKey: b64decode(pubB64),
    };
  } catch {
    return null;
  }
};

/** Persists keypair to localStorage. */
export const saveKeyPair = (kp: KeyPair): void => {
  if (!isBrowser()) throw new Error("saveKeyPair: not in browser");
  localStorage.setItem(PRIV_KEY_STORAGE, b64encode(kp.privateKey));
  localStorage.setItem(PUB_KEY_STORAGE, b64encode(kp.publicKey));
};

/** Returns existing keypair or generates+saves a new one. */
export const ensureKeyPair = (): KeyPair => {
  const existing = loadKeyPair();
  if (existing) return existing;
  const fresh = generateKeyPair();
  saveKeyPair(fresh);
  return fresh;
};

/** Removes keypair from localStorage. Call on logout / unpair. */
export const clearKeyPair = (): void => {
  if (!isBrowser()) return;
  localStorage.removeItem(PRIV_KEY_STORAGE);
  localStorage.removeItem(PUB_KEY_STORAGE);
};

/** Exports public key as base64 for upload to users.public_key. */
export const publicKeyToBase64 = (publicKey: Uint8Array): string => b64encode(publicKey);

/** Decodes a partner's base64 public key. */
export const publicKeyFromBase64 = (b64: string): Uint8Array => {
  const bytes = b64decode(b64);
  if (bytes.length !== 32) throw new Error(`invalid public key length: ${bytes.length}`);
  return bytes;
};
