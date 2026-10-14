import Foundation

/// Normalization used to decide whether two records are the same book.
enum BookMatching {
    /// Lowercase, accent-free, punctuation removed, subtitle and leading article dropped.
    static func normalizedTitle(_ title: String) -> String {
        let main = title.components(separatedBy: ":")[0]
        var folded = fold(main)
        for article in ["the ", "a ", "an "] where folded.hasPrefix(article) {
            folded.removeFirst(article.count)
            break
        }
        return folded
    }

    /// Word order does not matter, so "Le Guin, Ursula K." equals "Ursula K. Le Guin".
    static func normalizedAuthor(_ author: String) -> String {
        fold(author).split(separator: " ").sorted().joined(separator: " ")
    }

    static func isSameBook(titleA: String, authorA: String, titleB: String, authorB: String) -> Bool {
        normalizedTitle(titleA) == normalizedTitle(titleB)
            && normalizedAuthor(authorA) == normalizedAuthor(authorB)
    }

    private static func fold(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US"))
        let letters = folded.map { $0.isLetter || $0.isNumber ? $0 : " " }
        return String(letters).split(separator: " ").joined(separator: " ")
    }
}
