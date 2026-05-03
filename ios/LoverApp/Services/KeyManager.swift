import Foundation
import CryptoKit
import Security

// X25519 keypair stored in iOS Keychain. The private key never leaves the
// device (kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly + nosync). The
// public key is uploaded to users.public_key after first sign-in so the
// partner can derive the shared chat key.
//
// Why X25519: standard ECDH curve, fast, supported by CryptoKit on iOS 13+.
// The Secure Enclave only does P-256, so we keep the raw key in Keychain
// instead — simpler and the threat model (couples app on personal devices)
// doesn't justify SEP overhead.

@MainActor
final class KeyManager {

    static let shared = KeyManager()
    private init() {}

    private let service = "us.kit.michel.crypto"
    private let account = "x25519.private.v1"

    // MARK: - Public API

    /// Returns the device's X25519 private key, generating a fresh one on
    /// first call. Idempotent.
    func myPrivateKey() throws -> Curve25519.KeyAgreement.PrivateKey {
        if let existing = try loadPrivateKey() {
            return existing
        }
        let generated = Curve25519.KeyAgreement.PrivateKey()
        try storePrivateKey(generated)
        return generated
    }

    /// Convenience: returns base64(rawRepresentation) of the local public key.
    func myPublicKeyBase64() throws -> String {
        try myPrivateKey().publicKey.rawRepresentation.base64EncodedString()
    }

    /// Decode a partner's base64-encoded public key from the users table.
    static func decodePublicKey(base64: String) throws -> Curve25519.KeyAgreement.PublicKey {
        guard let data = Data(base64Encoded: base64) else {
            throw KeyError.invalidBase64
        }
        return try Curve25519.KeyAgreement.PublicKey(rawRepresentation: data)
    }

    /// Wipe the local private key. Used on sign-out / unpair so the next
    /// sign-in starts fresh (and can't decrypt prior partner's messages).
    func reset() {
        let q: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrService as String:  service,
            kSecAttrAccount as String:  account,
        ]
        SecItemDelete(q as CFDictionary)
    }

    // MARK: - Errors

    enum KeyError: Error {
        case invalidBase64
        case keychainStoreFailed(OSStatus)
        case keychainReadFailed(OSStatus)
        case decodeFailed
    }

    // MARK: - Keychain plumbing

    private func loadPrivateKey() throws -> Curve25519.KeyAgreement.PrivateKey? {
        var item: CFTypeRef?
        let q: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrService as String:  service,
            kSecAttrAccount as String:  account,
            kSecReturnData as String:   true,
            kSecMatchLimit as String:   kSecMatchLimitOne,
        ]
        let status = SecItemCopyMatching(q as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else { throw KeyError.decodeFailed }
            return try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: data)
        case errSecItemNotFound:
            return nil
        default:
            throw KeyError.keychainReadFailed(status)
        }
    }

    private func storePrivateKey(_ key: Curve25519.KeyAgreement.PrivateKey) throws {
        let data = key.rawRepresentation
        let attrs: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrService as String:  service,
            kSecAttrAccount as String:  account,
            kSecValueData as String:    data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecAttrSynchronizable as String: false,
        ]
        // Best-effort delete first (storePrivateKey is only called when load
        // returned nil, but be safe against race).
        let dq: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrService as String:  service,
            kSecAttrAccount as String:  account,
        ]
        SecItemDelete(dq as CFDictionary)

        let status = SecItemAdd(attrs as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeyError.keychainStoreFailed(status)
        }
    }
}
