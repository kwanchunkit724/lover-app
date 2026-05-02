import Foundation
import CryptoKit
import Security

/// Owns the device's long-term X25519 keypair and the derived per-couple symmetric key.
/// Private keys never leave the Keychain; public keys are uploaded to backend during pairing.
actor KeyManager {
    static let shared = KeyManager()

    private let identityKeyTag = "app.lover.identity.x25519.private"
    private let coupleKeyTag = "app.lover.couple.symmetric"
    private let coupleKeyAccessGroup = "group.app.lover.shared"

    private init() {}

    func ensureIdentityKey() throws -> Curve25519.KeyAgreement.PublicKey {
        if let existing = try loadIdentityPrivateKey() {
            return existing.publicKey
        }
        let fresh = Curve25519.KeyAgreement.PrivateKey()
        try storeIdentityPrivateKey(fresh)
        return fresh.publicKey
    }

    func deriveAndStoreCoupleKey(
        partnerPublicKey: Curve25519.KeyAgreement.PublicKey,
        coupleId: UUID
    ) throws {
        guard let identity = try loadIdentityPrivateKey() else {
            throw CryptoError.identityKeyMissing
        }
        let sharedSecret = try identity.sharedSecretFromKeyAgreement(with: partnerPublicKey)
        let coupleKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(coupleId.uuidString.utf8),
            sharedInfo: Data("lover-app/v1/couple-key".utf8),
            outputByteCount: 32
        )
        try storeCoupleKey(coupleKey)
    }

    func currentCoupleKey() throws -> SymmetricKey {
        guard let key = try loadCoupleKey() else {
            throw CryptoError.coupleKeyMissing
        }
        return key
    }

    func wipeAll() throws {
        try delete(tag: identityKeyTag, accessGroup: nil)
        try delete(tag: coupleKeyTag, accessGroup: coupleKeyAccessGroup)
    }

    // MARK: - Keychain helpers

    private func storeIdentityPrivateKey(_ key: Curve25519.KeyAgreement.PrivateKey) throws {
        try store(
            data: key.rawRepresentation,
            tag: identityKeyTag,
            accessGroup: nil,
            synchronizable: false
        )
    }

    private func loadIdentityPrivateKey() throws -> Curve25519.KeyAgreement.PrivateKey? {
        guard let raw = try load(tag: identityKeyTag, accessGroup: nil) else { return nil }
        return try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: raw)
    }

    private func storeCoupleKey(_ key: SymmetricKey) throws {
        let data = key.withUnsafeBytes { Data($0) }
        try store(
            data: data,
            tag: coupleKeyTag,
            accessGroup: coupleKeyAccessGroup,
            synchronizable: true   // iCloud Keychain so user's other devices can decrypt
        )
    }

    private func loadCoupleKey() throws -> SymmetricKey? {
        guard let raw = try load(tag: coupleKeyTag, accessGroup: coupleKeyAccessGroup) else {
            return nil
        }
        return SymmetricKey(data: raw)
    }

    private func store(data: Data, tag: String, accessGroup: String?, synchronizable: Bool) throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag.data(using: .utf8)!,
            kSecValueData as String: data,
            kSecAttrAccessible as String: synchronizable
                ? kSecAttrAccessibleAfterFirstUnlock
                : kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrSynchronizable as String: synchronizable
        ]
        if let group = accessGroup { query[kSecAttrAccessGroup as String] = group }

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw CryptoError.keychain(status) }
    }

    private func load(tag: String, accessGroup: String?) throws -> Data? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag.data(using: .utf8)!,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]
        if let group = accessGroup { query[kSecAttrAccessGroup as String] = group }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw CryptoError.keychain(status) }
        return result as? Data
    }

    private func delete(tag: String, accessGroup: String?) throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag.data(using: .utf8)!,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]
        if let group = accessGroup { query[kSecAttrAccessGroup as String] = group }
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CryptoError.keychain(status)
        }
    }
}

enum CryptoError: Error {
    case identityKeyMissing
    case coupleKeyMissing
    case keychain(OSStatus)
}
