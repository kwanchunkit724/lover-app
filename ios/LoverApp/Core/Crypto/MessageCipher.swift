import Foundation
import CryptoKit

/// Encrypts and decrypts message payloads with the couple's symmetric key.
/// Format on the wire: ChaCha20-Poly1305 sealed box. Nonce stored alongside ciphertext.
struct MessageCipher {
    let key: SymmetricKey

    struct Sealed {
        let ciphertext: Data
        let nonce: Data
        let tag: Data
    }

    func seal(_ plaintext: Data) throws -> Sealed {
        let nonce = ChaChaPoly.Nonce()
        let box = try ChaChaPoly.seal(plaintext, using: key, nonce: nonce)
        return Sealed(
            ciphertext: box.ciphertext,
            nonce: Data(nonce),
            tag: box.tag
        )
    }

    func open(_ sealed: Sealed) throws -> Data {
        let nonce = try ChaChaPoly.Nonce(data: sealed.nonce)
        let box = try ChaChaPoly.SealedBox(
            nonce: nonce,
            ciphertext: sealed.ciphertext,
            tag: sealed.tag
        )
        return try ChaChaPoly.open(box, using: key)
    }

    func sealString(_ text: String) throws -> Sealed {
        try seal(Data(text.utf8))
    }

    func openString(_ sealed: Sealed) throws -> String {
        let bytes = try open(sealed)
        guard let text = String(data: bytes, encoding: .utf8) else {
            throw CipherError.invalidUTF8
        }
        return text
    }
}

enum CipherError: Error {
    case invalidUTF8
}
