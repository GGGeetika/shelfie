import Foundation
import SwiftData

@Model
final class Book {
    var id: UUID = UUID()
    var title: String
    var author: String
    /// Canonical ISBN-13 when known.
    var isbn: String?
    var coverURLString: String?
    var pageCount: Int?
    var bookDescription: String?
    var statusRaw: String = BookStatus.wantToRead.rawValue
    var privateNote: String?
    var tags: [String] = []
    var addedAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \Recommendation.book)
    var recommendations: [Recommendation] = []
    @Relationship(deleteRule: .cascade, inverse: \ShelfBook.book)
    var shelfBooks: [ShelfBook] = []

    init(
        title: String,
        author: String,
        isbn: String? = nil,
        coverURLString: String? = nil,
        pageCount: Int? = nil,
        bookDescription: String? = nil,
        addedAt: Date = .now
    ) {
        self.title = title
        self.author = author
        self.isbn = isbn
        self.coverURLString = coverURLString
        self.pageCount = pageCount
        self.bookDescription = bookDescription
        self.addedAt = addedAt
    }

    var status: BookStatus {
        get { BookStatus(rawValue: statusRaw) ?? .wantToRead }
        set { statusRaw = newValue.rawValue }
    }

    var coverURL: URL? { coverURLString.flatMap(URL.init(string:)) }
}
