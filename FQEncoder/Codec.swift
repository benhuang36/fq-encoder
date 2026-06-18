import Foundation
import CryptoKit

/// UserDefaults key for the user's preset password (the encoding key).
let passwordDefaultsKey = "fq.encodingPassword"

/// Reversible codec that maps arbitrary text into a string built from only
/// 7 symbols: F, U, C, K, Y, O, u  (note: uppercase "U" and lowercase "u"
/// are distinct symbols).
///
/// Scheme (three stages):
///  1. Keystream XOR — the input's UTF-8 bytes are XOR'd with a keystream
///     derived from the password (SHA-256 in counter mode). This destroys any
///     stable per-character mapping: the same input byte produces different
///     output depending on its position and on the password, so the output
///     can't be read by memorising a fixed substitution table.
///  2. Bidirectional diffusion — a forward + backward additive chain (O(n))
///     makes every output byte depend on every input byte, so changing one
///     byte avalanches through the whole result and there are no shared
///     prefixes between similar inputs.
///  3. Base-7 packing — each resulting byte (0...255) is written as exactly
///     3 base-7 digits (7^3 = 343 ≥ 256), each digit selecting one symbol.
///
/// Decoding reverses all stages. Note: this is obfuscation, not encryption —
/// it is keyed but unauthenticated, and an embedded key can be recovered from
/// the binary. Its job is to stop casual readers from guessing the method.
enum Codec {
    static let alphabet: [Character] = ["F", "U", "C", "K", "Y", "O", "u"]
    private static let radix = 7

    /// Fast lookup from symbol -> digit value.
    private static let valueOf: [Character: Int] = {
        var map = [Character: Int]()
        for (i, c) in alphabet.enumerated() { map[c] = i }
        return map
    }()

    enum CodecError: LocalizedError {
        case invalidLength
        case invalidCharacter(Character)
        case invalidByte
        case notUTF8

        var errorDescription: String? {
            switch self {
            case .invalidLength:
                return "輸入長度必須是 3 的倍數，這不是合法的編碼字串。"
            case .invalidCharacter(let c):
                return "包含非法字元「\(c)」，編碼字串只能由 F U C K Y O u 組成。"
            case .invalidByte:
                return "包含無效的編碼組合，這不是由 FQEncoder 產生的字串。"
            case .notUTF8:
                return "解碼失敗，可能是密碼不正確，或這不是 FQEncoder 編出來的字串。"
            }
        }
    }

    // MARK: - Public keyed API

    /// Encode any string into the 7-symbol alphabet using `key` as the password.
    static func encode(_ input: String, key: String) -> String {
        var bytes = Array(input.utf8)
        applyKeystream(&bytes, key: key)
        diffuse(&bytes)
        return packBase7(bytes)
    }

    /// Decode a 7-symbol string back to the original text using `key`.
    static func decode(_ input: String, key: String) throws -> String {
        var bytes = try unpackBase7(input)
        undiffuse(&bytes)
        applyKeystream(&bytes, key: key)
        guard let decoded = String(bytes: bytes, encoding: .utf8) else {
            throw CodecError.notUTF8
        }
        return decoded
    }

    /// Whether `input` looks like a valid encoded string for the given `key`.
    /// Used by the clipboard monitor to decide encode-vs-decode automatically.
    static func looksEncoded(_ input: String, key: String) -> Bool {
        guard !input.isEmpty, input.count % 3 == 0 else { return false }
        for c in input where valueOf[c] == nil { return false }
        return (try? decode(input, key: key)) != nil
    }

    // MARK: - Keystream (SHA-256 counter mode)

    /// Deterministic keystream of `count` bytes derived from `key`. XOR is its
    /// own inverse, so the same call is used for both encode and decode.
    private static func applyKeystream(_ bytes: inout [UInt8], key: String) {
        guard !bytes.isEmpty else { return }
        let seed = Data(SHA256.hash(data: Data("FQEncoder.v1:\(key)".utf8)))
        var produced = 0
        var counter: UInt64 = 0
        while produced < bytes.count {
            var block = seed
            withUnsafeBytes(of: counter.littleEndian) { block.append(contentsOf: $0) }
            for b in SHA256.hash(data: block) where produced < bytes.count {
                bytes[produced] ^= b
                produced += 1
            }
            counter &+= 1
        }
    }

    // MARK: - Bidirectional diffusion (content-dependent, O(n))

    // Fixed initial accumulators for the two passes. The keystream layer above
    // already supplies the keyed pseudo-randomness; these only need to be
    // deterministic and non-zero.
    private static let ivForward: UInt8 = 0x9E
    private static let ivBackward: UInt8 = 0x7F

    /// Spread every byte's influence across the whole buffer so a single-byte
    /// change avalanches through the entire output (no shared prefixes).
    /// Forward pass folds in everything to the left; backward pass folds in
    /// everything to the right — together every output byte depends on every
    /// input byte. Uses addition mod 256, which is exactly reversible.
    private static func diffuse(_ b: inout [UInt8]) {
        guard !b.isEmpty else { return }
        // Forward: B[i] = A[i] + B[i-1]
        var acc = ivForward
        for i in b.indices {
            b[i] = b[i] &+ acc
            acc = b[i]
        }
        // Backward: C[i] = B[i] + C[i+1]
        acc = ivBackward
        var i = b.count - 1
        while i >= 0 {
            b[i] = b[i] &+ acc
            acc = b[i]
            i -= 1
        }
    }

    /// Inverse of `diffuse`: undo the backward pass first, then the forward one.
    private static func undiffuse(_ b: inout [UInt8]) {
        guard !b.isEmpty else { return }
        // Invert backward: B[i] = C[i] - C[i+1]
        var next = ivBackward
        var i = b.count - 1
        while i >= 0 {
            let cur = b[i]
            b[i] = cur &- next
            next = cur
            i -= 1
        }
        // Invert forward: A[i] = B[i] - B[i-1]
        var prev = ivForward
        for j in b.indices {
            let cur = b[j]
            b[j] = cur &- prev
            prev = cur
        }
    }

    // MARK: - Base-7 packing

    private static func packBase7(_ bytes: [UInt8]) -> String {
        var result = ""
        result.reserveCapacity(bytes.count * 3)
        for byte in bytes {
            let v = Int(byte)
            result.append(alphabet[(v / 49) % radix])
            result.append(alphabet[(v / 7) % radix])
            result.append(alphabet[v % radix])
        }
        return result
    }

    private static func unpackBase7(_ input: String) throws -> [UInt8] {
        let chars = Array(input)
        guard chars.count % 3 == 0 else { throw CodecError.invalidLength }

        var bytes = [UInt8]()
        bytes.reserveCapacity(chars.count / 3)
        var i = 0
        while i < chars.count {
            guard let d1 = valueOf[chars[i]] else { throw CodecError.invalidCharacter(chars[i]) }
            guard let d2 = valueOf[chars[i + 1]] else { throw CodecError.invalidCharacter(chars[i + 1]) }
            guard let d3 = valueOf[chars[i + 2]] else { throw CodecError.invalidCharacter(chars[i + 2]) }
            // 7^3 = 343 > 256, so some valid-looking triples decode above 255.
            // Reject them instead of overflowing UInt8 (which would crash).
            let value = d1 * 49 + d2 * 7 + d3
            guard value <= 255 else { throw CodecError.invalidByte }
            bytes.append(UInt8(value))
            i += 3
        }
        return bytes
    }
}
