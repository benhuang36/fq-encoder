import Foundation

/// Reversible codec that maps arbitrary text into a string built from only
/// 7 symbols: F, U, C, K, Y, O, u  (note: uppercase "U" and lowercase "u"
/// are distinct symbols).
///
/// Scheme: the input is taken as UTF-8 bytes. Each byte (0...255) is written
/// as exactly 3 base-7 digits (7^3 = 343 ≥ 256), and each digit selects one
/// symbol from the alphabet. Decoding reverses this 3-symbols-per-byte mapping
/// and rebuilds the UTF-8 string. Fixed-width grouping makes the encoding
/// unambiguous and trivially reversible.
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
                return "解碼後的位元組無法還原為文字。"
            }
        }
    }

    /// Encode any string into the 7-symbol alphabet.
    static func encode(_ input: String) -> String {
        var result = ""
        result.reserveCapacity(input.utf8.count * 3)
        for byte in input.utf8 {
            let v = Int(byte)
            result.append(alphabet[(v / 49) % radix])
            result.append(alphabet[(v / 7) % radix])
            result.append(alphabet[v % radix])
        }
        return result
    }

    /// Decode a 7-symbol string back to the original text.
    static func decode(_ input: String) throws -> String {
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

        guard let decoded = String(bytes: bytes, encoding: .utf8) else {
            throw CodecError.notUTF8
        }
        return decoded
    }

    /// Whether `input` looks like a valid encoded string produced by `encode`.
    /// Used by the clipboard monitor to decide encode-vs-decode automatically.
    static func looksEncoded(_ input: String) -> Bool {
        guard !input.isEmpty, input.count % 3 == 0 else { return false }
        for c in input where valueOf[c] == nil { return false }
        return (try? decode(input)) != nil
    }
}
