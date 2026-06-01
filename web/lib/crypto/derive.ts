// HKDF-SHA256 derivation of the per-couple chat key.
//
// Wire format MUST stay byte-compatible with iOS + Android:
//
//   shared  = X25519(my_priv, partner_pub)              // 32 bytes
//   salt    = UTF-8 bytes of coupleId.toUpperCase()
//   info    = UTF-8 bytes of "us.chat.v1"
//   chatKey = HKDF-SHA256(shared, salt, info, 32 bytes)
//
// Swift's UUID.uuidString defaults to UPPERCASE, so iOS derives with
// uppercase salt. Kotlin UUID.toString and JS crypto.randomUUID return
// LOWERCASE. We `.toUpperCase()` here so the web client lands on the
// same chatKey bytes as iOS without coordination needed.
//
// Realtime channel naming is different — that uses lowercase
// `presence:<lowercase couple uuid>`. Do NOT confuse the two.

import { x25519 } from "@noble/curves/ed25519.js";
import { hkdf } from "@noble/hashes/hkdf.js";
import { sha256 } from "@noble/hashes/sha2.js";

const INFO_BYTES = new TextEncoder().encode("us.chat.v1");

/**
 * Derives the 32-byte symmetric chat key from this device's private key,
 * the partner's public key, and the couple id.
 *
 * @param myPrivateKey  this device's 32-byte X25519 private scalar
 * @param partnerPubKey partner's 32-byte X25519 public u-coordinate
 * @param coupleId      the couples.id UUID string (any case — will be uppercased)
 * @returns 32 bytes suitable for AES-GCM-256
 */
export const deriveChatKey = (
  myPrivateKey: Uint8Array,
  partnerPubKey: Uint8Array,
  coupleId: string,
): Uint8Array => {
  if (myPrivateKey.length !== 32) {
    throw new Error(`deriveChatKey: bad private key length ${myPrivateKey.length}`);
  }
  if (partnerPubKey.length !== 32) {
    throw new Error(`deriveChatKey: bad public key length ${partnerPubKey.length}`);
  }
  const shared = x25519.getSharedSecret(myPrivateKey, partnerPubKey);
  const salt = new TextEncoder().encode(coupleId.toUpperCase());
  return hkdf(sha256, shared, salt, INFO_BYTES, 32);
};
