import XCTest
@testable import Shelfie

final class MockHTTPClient: HTTPClient, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [URL] = []
    private let handler: @Sendable (URL) -> (Int, String)

    init(handler: @escaping @Sendable (URL) -> (Int, String)) {
        self.handler = handler
    }

    var requests: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    private func record(_ url: URL) {
        lock.lock()
        recorded.append(url)
        lock.unlock()
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let url = request.url!
        record(url)
        let (status, body) = handler(url)
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (Data(body.utf8), response)
    }
}

enum Fixtures {
    static let openLibrary = """
    {"numFound":2,"docs":[
      {"key":"/works/OL1W","title":"Piranesi","author_name":["Susanna Clarke"],
       "isbn":["0306406152","9780306406157"],"cover_i":10527843,"number_of_pages_median":272},
      {"key":"/works/OL2W","title":"Jonathan Strange & Mr Norrell","author_name":["Susanna Clarke"],"cover_i":1}
    ]}
    """

    static let openLibraryEmpty = #"{"numFound":0,"docs":[]}"#

    static let googleBooks = """
    {"items":[{"volumeInfo":{"title":"Piranesi","authors":["Susanna Clarke"],
      "description":"A strange house.","pageCount":272,
      "industryIdentifiers":[{"type":"ISBN_10","identifier":"0306406152"},{"type":"ISBN_13","identifier":"9780306406157"}],
      "imageLinks":{"thumbnail":"http://books.google.com/books/content?id=abc&zoom=1&edge=curl&source=gbs_api"}}}]}
    """

    static let googleBooksEmpty = #"{"totalItems":0}"#

    static let workPlain = #"{"description":"An endless house of statues and tides."}"#
    static let workTyped = #"{"description":{"type":"/type/text","value":"Typed description."}}"#
}

final class BookLookupTests: XCTestCase {
    private func lookup(_ handler: @escaping @Sendable (URL) -> (Int, String)) -> (BookLookup, MockHTTPClient) {
        let mock = MockHTTPClient(handler: handler)
        return (BookLookup(http: mock), mock)
    }

    func testOpenLibraryResultsAreParsedAndGoogleIsNotCalled() async throws {
        let (service, mock) = lookup { _ in (200, Fixtures.openLibrary) }
        let results = try await service.search(.text("piranesi"))

        XCTAssertEqual(results.count, 2)
        let first = results[0]
        XCTAssertEqual(first.title, "Piranesi")
        XCTAssertEqual(first.author, "Susanna Clarke")
        XCTAssertEqual(first.isbn, "9780306406157")
        XCTAssertEqual(first.pageCount, 272)
        XCTAssertEqual(first.coverURL?.absoluteString, "https://covers.openlibrary.org/b/id/10527843-L.jpg?default=false")
        XCTAssertEqual(first.openLibraryWorkKey, "/works/OL1W")
        XCTAssertNil(results[1].isbn)
        XCTAssertTrue(mock.requests.allSatisfy { $0.host == "openlibrary.org" })
    }

    func testFallsBackToGoogleWhenOpenLibraryIsEmpty() async throws {
        let (service, mock) = lookup { url in
            url.host == "openlibrary.org" ? (200, Fixtures.openLibraryEmpty) : (200, Fixtures.googleBooks)
        }
        let results = try await service.search(.text("piranesi"))

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].description, "A strange house.")
        XCTAssertEqual(results[0].isbn, "9780306406157")
        XCTAssertEqual(mock.requests.map(\.host), ["openlibrary.org", "www.googleapis.com"])
    }

    func testGoogleCoverIsHTTPSWithoutPageCurl() async throws {
        let (service, _) = lookup { url in
            url.host == "openlibrary.org" ? (200, Fixtures.openLibraryEmpty) : (200, Fixtures.googleBooks)
        }
        let results = try await service.search(.text("piranesi"))
        XCTAssertEqual(results[0].coverURL?.absoluteString, "https://books.google.com/books/content?id=abc&zoom=1&source=gbs_api")
    }

    func testFallsBackToGoogleWhenOpenLibraryFails() async throws {
        let (service, _) = lookup { url in
            url.host == "openlibrary.org" ? (500, "oops") : (200, Fixtures.googleBooks)
        }
        let results = try await service.search(.text("piranesi"))
        XCTAssertEqual(results.map(\.title), ["Piranesi"])
    }

    func testFallsBackToGoogleWhenOpenLibraryReturnsMalformedJSON() async throws {
        let (service, _) = lookup { url in
            url.host == "openlibrary.org" ? (200, "<html>not json</html>") : (200, Fixtures.googleBooks)
        }
        let results = try await service.search(.text("piranesi"))
        XCTAssertEqual(results.map(\.title), ["Piranesi"])
    }

    func testBothEmptyReturnsNoResults() async throws {
        let (service, _) = lookup { url in
            url.host == "openlibrary.org" ? (200, Fixtures.openLibraryEmpty) : (200, Fixtures.googleBooksEmpty)
        }
        let results = try await service.search(.text("zzzz"))
        XCTAssertTrue(results.isEmpty)
    }

    func testThrowsWhenBothSourcesFail() async {
        let (service, _) = lookup { _ in (503, "down") }
        do {
            _ = try await service.search(.text("piranesi"))
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? LookupError, .badStatus(503))
        }
    }

    func testEmptyQueryMakesNoRequests() async throws {
        let (service, mock) = lookup { _ in (200, Fixtures.openLibrary) }
        let results = try await service.search(BookQuery(title: "  ", author: nil))
        XCTAssertTrue(results.isEmpty)
        XCTAssertTrue(mock.requests.isEmpty)
    }

    func testISBNQueryUsesISBNParameter() async throws {
        let (service, mock) = lookup { _ in (200, Fixtures.openLibrary) }
        _ = try await service.search(BookQuery(isbn: "9780306406157"))
        XCTAssertTrue(mock.requests[0].absoluteString.contains("isbn=9780306406157"))
    }

    func testTitleAndAuthorQueryUsesBothParametersEncoded() async throws {
        let (service, mock) = lookup { _ in (200, Fixtures.openLibrary) }
        _ = try await service.search(BookQuery(title: "Jonathan Strange & Mr Norrell", author: "Susanna Clarke"))
        let url = mock.requests[0].absoluteString
        XCTAssertTrue(url.contains("title=Jonathan%20Strange%20%26%20Mr%20Norrell"), url)
        XCTAssertTrue(url.contains("author=Susanna%20Clarke"), url)
    }

    func testGoogleTitleAuthorQueryUsesFieldOperators() async throws {
        let (service, mock) = lookup { url in
            url.host == "openlibrary.org" ? (200, Fixtures.openLibraryEmpty) : (200, Fixtures.googleBooks)
        }
        _ = try await service.search(BookQuery(title: "Piranesi", author: "Clarke"))
        let google = mock.requests[1].absoluteString
        XCTAssertTrue(google.contains("intitle:Piranesi"), google)
        XCTAssertTrue(google.contains("inauthor:Clarke"), google)
    }

    func testLoneISBN10IsConvertedToISBN13() async throws {
        let body = #"{"docs":[{"title":"Old Edition","author_name":["A"],"isbn":["0306406152"]}]}"#
        let (service, _) = lookup { _ in (200, body) }
        let results = try await service.search(.text("old"))
        XCTAssertEqual(results[0].isbn, "9780306406157")
    }

    func testDetailsFillsDescriptionFromPlainWorkText() async {
        let (service, _) = lookup { _ in (200, Fixtures.workPlain) }
        let book = BookMetadata(title: "Piranesi", author: "Susanna Clarke", openLibraryWorkKey: "/works/OL1W")
        let enriched = await service.details(for: book)
        XCTAssertEqual(enriched.description, "An endless house of statues and tides.")
    }

    func testDetailsFillsDescriptionFromTypedWorkText() async {
        let (service, _) = lookup { _ in (200, Fixtures.workTyped) }
        let book = BookMetadata(title: "Piranesi", author: "Susanna Clarke", openLibraryWorkKey: "/works/OL1W")
        let enriched = await service.details(for: book)
        XCTAssertEqual(enriched.description, "Typed description.")
    }

    func testDetailsKeepsBookWhenWorkRequestFails() async {
        let (service, _) = lookup { _ in (404, "") }
        let book = BookMetadata(title: "Piranesi", author: "Susanna Clarke", openLibraryWorkKey: "/works/OL1W")
        let enriched = await service.details(for: book)
        XCTAssertEqual(enriched, book)
    }

    func testDetailsDoesNotOverwriteExistingDescription() async {
        let (service, mock) = lookup { _ in (200, Fixtures.workPlain) }
        let book = BookMetadata(title: "P", author: "A", description: "Mine", openLibraryWorkKey: "/works/OL1W")
        let enriched = await service.details(for: book)
        XCTAssertEqual(enriched.description, "Mine")
        XCTAssertTrue(mock.requests.isEmpty)
    }

    func testLookupByISBNReturnsEnrichedBookWithScannedISBN() async throws {
        let (service, _) = lookup { url in
            url.path.hasPrefix("/works/") ? (200, Fixtures.workPlain) : (200, Fixtures.openLibrary)
        }
        let book = try await service.lookup(isbn: "978-0-306-40615-7")
        XCTAssertEqual(book?.title, "Piranesi")
        XCTAssertEqual(book?.isbn, "9780306406157")
        XCTAssertEqual(book?.description, "An endless house of statues and tides.")
    }

    func testLookupRejectsInvalidISBNWithoutNetwork() async throws {
        let (service, mock) = lookup { _ in (200, Fixtures.openLibrary) }
        let book = try await service.lookup(isbn: "9780306406158")
        XCTAssertNil(book)
        XCTAssertTrue(mock.requests.isEmpty)
    }
}

final class ISBNTests: XCTestCase {
    func testValidISBN13() {
        XCTAssertEqual(ISBN.normalize("978-0-306-40615-7"), "9780306406157")
    }

    func testInvalidChecksumIsRejected() {
        XCTAssertNil(ISBN.normalize("9780306406158"))
    }

    func testValidISBN10IncludingX() {
        XCTAssertEqual(ISBN.normalize("0306406152"), "0306406152")
        XCTAssertEqual(ISBN.normalize("0-8044-2957-X"), "080442957X")
    }

    func testNonBookEAN13IsRejected() {
        // Valid EAN-13 checksum but not a 978/979 book code.
        XCTAssertNil(ISBN.normalize("4006381333931"))
    }

    func testCanonical13ConvertsISBN10() {
        XCTAssertEqual(ISBN.canonical13("0306406152"), "9780306406157")
        XCTAssertEqual(ISBN.canonical13("9780306406157"), "9780306406157")
        XCTAssertNil(ISBN.canonical13("hello"))
    }
}

final class BookMatchingTests: XCTestCase {
    func testTitlesIgnoreCaseAccentsPunctuationArticlesAndSubtitles() {
        XCTAssertEqual(BookMatching.normalizedTitle("The Left Hand of Darkness"), BookMatching.normalizedTitle("left hand of darkness"))
        XCTAssertEqual(BookMatching.normalizedTitle("Piranesi: A Novel"), BookMatching.normalizedTitle("Piranesi"))
        XCTAssertEqual(BookMatching.normalizedTitle("Amélie"), BookMatching.normalizedTitle("AMELIE"))
    }

    func testAuthorsIgnoreOrderAndInitialsPunctuation() {
        XCTAssertEqual(BookMatching.normalizedAuthor("Le Guin, Ursula K."), BookMatching.normalizedAuthor("Ursula K. Le Guin"))
        XCTAssertEqual(BookMatching.normalizedAuthor("J.R.R. Tolkien"), BookMatching.normalizedAuthor("J. R. R. Tolkien"))
    }

    func testDifferentBooksDoNotMatch() {
        XCTAssertFalse(BookMatching.isSameBook(titleA: "Dune", authorA: "Frank Herbert", titleB: "Dune", authorB: "Brian Herbert"))
        XCTAssertFalse(BookMatching.isSameBook(titleA: "Dune", authorA: "Frank Herbert", titleB: "Emma", authorB: "Frank Herbert"))
    }
}
