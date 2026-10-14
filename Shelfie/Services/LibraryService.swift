import Foundation
import SwiftData

/// Adds books to the library without creating duplicates.
@MainActor
struct LibraryService {
    let context: ModelContext

    struct AddResult {
        let book: Book
        let recommendation: Recommendation
        let isNewBook: Bool
    }

    /// Creates the Book (or reuses a match on ISBN, else normalized title + author)
    /// and always adds a new Recommendation to it.
    @discardableResult
    func add(
        _ metadata: BookMetadata,
        source: SourceType,
        sourceName: String? = nil,
        note: String? = nil,
        at date: Date = .now
    ) throws -> AddResult {
        let name = Self.clean(sourceName)
        let book: Book
        let isNew: Bool
        if let existing = try findExisting(isbn: metadata.isbn, title: metadata.title, author: metadata.author) {
            book = existing
            isNew = false
            fillGaps(of: existing, from: metadata)
        } else {
            book = Book(
                title: metadata.title,
                author: metadata.author,
                isbn: metadata.isbn.flatMap(ISBN.canonical13),
                coverURLString: metadata.coverURL?.absoluteString,
                pageCount: metadata.pageCount,
                bookDescription: metadata.description,
                addedAt: date
            )
            context.insert(book)
            isNew = true
        }

        let recommendation = Recommendation(
            sourceType: source,
            friendName: source == .friend ? name : nil,
            note: Self.clean(note),
            createdAt: date
        )
        context.insert(recommendation)
        recommendation.book = book
        if source == .club, let name {
            recommendation.club = try findOrCreateClub(named: name)
        }
        try context.save()
        return AddResult(book: book, recommendation: recommendation, isNewBook: isNew)
    }

    func findExisting(isbn: String?, title: String, author: String) throws -> Book? {
        let books = try context.fetch(FetchDescriptor<Book>())
        if let canonical = isbn.flatMap(ISBN.canonical13),
           let match = books.first(where: { $0.isbn.flatMap(ISBN.canonical13) == canonical }) {
            return match
        }
        return books.first {
            BookMatching.isSameBook(titleA: $0.title, authorA: $0.author, titleB: title, authorB: author)
        }
    }

    private func findOrCreateClub(named name: String) throws -> Club {
        let clubs = try context.fetch(FetchDescriptor<Club>())
        if let match = clubs.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            return match
        }
        let club = Club(name: name)
        context.insert(club)
        return club
    }

    private func fillGaps(of book: Book, from metadata: BookMetadata) {
        if book.isbn == nil { book.isbn = metadata.isbn.flatMap(ISBN.canonical13) }
        if book.coverURLString == nil { book.coverURLString = metadata.coverURL?.absoluteString }
        if book.pageCount == nil { book.pageCount = metadata.pageCount }
        if book.bookDescription == nil { book.bookDescription = metadata.description }
    }

    private static func clean(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
