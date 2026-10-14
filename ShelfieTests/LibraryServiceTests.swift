import SwiftData
import XCTest
@testable import Shelfie

@MainActor
final class LibraryServiceTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }
    private var service: LibraryService { LibraryService(context: context) }

    override func setUpWithError() throws {
        container = try Persistence.makeContainer(inMemory: true)
    }

    private func piranesi(isbn: String? = "9780306406157") -> BookMetadata {
        BookMetadata(title: "Piranesi", author: "Susanna Clarke", isbn: isbn, pageCount: 272)
    }

    func testAddingCreatesBookAndRecommendation() throws {
        let result = try service.add(piranesi(), source: .friend, sourceName: "Maya", note: "Read this!")

        XCTAssertTrue(result.isNewBook)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Book>()).count, 1)
        XCTAssertEqual(result.book.status, .wantToRead)
        XCTAssertEqual(result.recommendation.sourceType, .friend)
        XCTAssertEqual(result.recommendation.friendName, "Maya")
        XCTAssertEqual(result.recommendation.note, "Read this!")
        XCTAssertEqual(result.book.recommendations.count, 1)
    }

    func testSameISBNAddsRecommendationNotDuplicateBook() throws {
        try service.add(piranesi(), source: .friend)
        let second = try service.add(piranesi(), source: .me)

        XCTAssertFalse(second.isNewBook)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Book>()).count, 1)
        XCTAssertEqual(second.book.recommendations.count, 2)
    }

    func testISBN10AndISBN13MatchTheSameBook() throws {
        try service.add(piranesi(isbn: "9780306406157"), source: .friend)
        let second = try service.add(piranesi(isbn: "0306406152"), source: .me)
        XCTAssertFalse(second.isNewBook)
    }

    func testWithoutISBNMatchesOnNormalizedTitleAndAuthor() throws {
        try service.add(BookMetadata(title: "The Piranesi", author: "Clarke, Susanna"), source: .me)
        let second = try service.add(BookMetadata(title: "piranesi", author: "Susanna Clarke"), source: .club, sourceName: "Tuesday Club")
        XCTAssertFalse(second.isNewBook)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Book>()).count, 1)
    }

    func testDifferentBooksStaySeparate() throws {
        try service.add(piranesi(), source: .me)
        let other = try service.add(BookMetadata(title: "Emma", author: "Jane Austen", isbn: nil), source: .me)
        XCTAssertTrue(other.isNewBook)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Book>()).count, 2)
    }

    func testExistingBookGainsMissingMetadata() throws {
        try service.add(BookMetadata(title: "Piranesi", author: "Susanna Clarke"), source: .me)
        let second = try service.add(piranesi(), source: .me)
        XCTAssertEqual(second.book.isbn, "9780306406157")
        XCTAssertEqual(second.book.pageCount, 272)
    }

    func testClubIsReusedCaseInsensitively() throws {
        try service.add(piranesi(), source: .club, sourceName: "Tuesday Club")
        try service.add(BookMetadata(title: "Emma", author: "Jane Austen"), source: .club, sourceName: "tuesday club")
        XCTAssertEqual(try context.fetch(FetchDescriptor<Club>()).count, 1)
    }

    func testBlankNameAndNoteAreStoredAsNil() throws {
        let result = try service.add(piranesi(), source: .friend, sourceName: "  ", note: "")
        XCTAssertNil(result.recommendation.friendName)
        XCTAssertNil(result.recommendation.note)
    }

    func testMeSourceIgnoresName() throws {
        let result = try service.add(piranesi(), source: .me, sourceName: "Someone")
        XCTAssertNil(result.recommendation.friendName)
        XCTAssertNil(result.recommendation.club)
    }

    func testDeletingBookRemovesItsRecommendations() throws {
        let result = try service.add(piranesi(), source: .me)
        context.delete(result.book)
        try context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<Recommendation>()).count, 0)
    }
}
