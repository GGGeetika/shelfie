import Foundation

enum ISBN {
    /// Digits (and a trailing X for ISBN-10) if `raw` is a valid ISBN, else nil.
    /// A 13-digit code must start 978 or 979, so ordinary product barcodes are rejected.
    static func normalize(_ raw: String) -> String? {
        let cleaned = raw.uppercased().filter { $0.isASCII && ($0.isNumber || $0 == "X") }
        switch cleaned.count {
        case 13:
            guard cleaned.hasPrefix("978") || cleaned.hasPrefix("979"), isValid13(cleaned) else { return nil }
            return cleaned
        case 10:
            return isValid10(cleaned) ? cleaned : nil
        default:
            return nil
        }
    }

    /// The ISBN-13 form of any valid ISBN, so 10- and 13-digit forms of one edition compare equal.
    static func canonical13(_ raw: String) -> String? {
        guard let isbn = normalize(raw) else { return nil }
        if isbn.count == 13 { return isbn }
        let body = "978" + isbn.prefix(9)
        let sum = body.compactMap(\.wholeNumberValue).enumerated().reduce(0) { $0 + $1.element * ($1.offset % 2 == 0 ? 1 : 3) }
        return body + String((10 - sum % 10) % 10)
    }

    private static func isValid13(_ s: String) -> Bool {
        let digits = s.compactMap(\.wholeNumberValue)
        guard digits.count == 13 else { return false }
        let sum = digits.enumerated().reduce(0) { $0 + $1.element * ($1.offset % 2 == 0 ? 1 : 3) }
        return sum % 10 == 0
    }

    private static func isValid10(_ s: String) -> Bool {
        var sum = 0
        for (index, char) in s.enumerated() {
            let value: Int
            if char == "X" {
                guard index == 9 else { return false }
                value = 10
            } else if let digit = char.wholeNumberValue {
                value = digit
            } else {
                return false
            }
            sum += value * (10 - index)
        }
        return sum % 11 == 0
    }
}
