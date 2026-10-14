import Foundation

struct BookMetadata: Equatable, Hashable, Identifiable, Sendable {
    var title: String
    var author: String
    var isbn: String?
    var coverURL: URL?
    var pageCount: Int?
    var description: String?
    /// Open Library work key (e.g. "/works/OL1W"), used to fetch a description later.
    var openLibraryWorkKey: String?

    var id: String { isbn ?? "\(title)|\(author)" }
}

struct BookQuery: Equatable, Sendable {
    var title: String?
    var author: String?
    var isbn: String?
    /// Free text from a search box.
    var text: String?

    init(title: String? = nil, author: String? = nil, isbn: String? = nil, text: String? = nil) {
        self.title = Self.clean(title)
        self.author = Self.clean(author)
        self.isbn = Self.clean(isbn)
        self.text = Self.clean(text)
    }

    static func text(_ text: String) -> BookQuery { BookQuery(text: text) }

    var isEmpty: Bool { title == nil && author == nil && isbn == nil && text == nil }

    private static func clean(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }
}

enum LookupError: Error, Equatable {
    case badStatus(Int)
}

protocol HTTPClient: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

extension URLSession: HTTPClient {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await self.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, http)
    }
}

/// Looks books up in Open Library first and falls back to Google Books.
struct BookLookup: Sendable {
    var http: any HTTPClient = URLSession.shared
    var openLibraryBase = URL(string: "https://openlibrary.org")!
    var googleBooksBase = URL(string: "https://www.googleapis.com")!

    static let live = BookLookup()

    // MARK: Public API

    func search(_ query: BookQuery) async throws -> [BookMetadata] {
        guard !query.isEmpty else { return [] }
        do {
            let results = try await searchOpenLibrary(query)
            if !results.isEmpty { return results }
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw error
        } catch {
            // Open Library failed or returned something unreadable; try Google Books.
        }
        return try await searchGoogleBooks(query)
    }

    /// Best match for an ISBN, with the description filled in when one can be found.
    func lookup(isbn: String) async throws -> BookMetadata? {
        guard let normalized = ISBN.normalize(isbn) else { return nil }
        guard var best = try await search(BookQuery(isbn: normalized)).first else { return nil }
        best.isbn = ISBN.canonical13(normalized)
        return await details(for: best)
    }

    /// Fills in the description from the Open Library work record when it is missing.
    func details(for book: BookMetadata) async -> BookMetadata {
        guard book.description == nil, let key = book.openLibraryWorkKey else { return book }
        do {
            let data = try await get(openLibraryBase.appendingPathComponent(key + ".json"))
            let work = try JSONDecoder().decode(OLWork.self, from: data)
            var updated = book
            updated.description = work.description?.value.trimmingCharacters(in: .whitespacesAndNewlines)
            if updated.description?.isEmpty == true { updated.description = nil }
            return updated
        } catch {
            return book
        }
    }

    // MARK: Open Library

    private func searchOpenLibrary(_ query: BookQuery) async throws -> [BookMetadata] {
        var items: [(String, String)] = []
        if let isbn = query.isbn {
            items.append(("isbn", isbn))
        } else if let text = query.text {
            items.append(("q", text))
        } else {
            if let title = query.title { items.append(("title", title)) }
            if let author = query.author { items.append(("author", author)) }
        }
        items.append(("limit", "10"))
        items.append(("fields", "key,title,author_name,isbn,cover_i,number_of_pages_median"))

        let url = makeURL(openLibraryBase, path: "search.json", items: items)
        let response = try JSONDecoder().decode(OLSearchResponse.self, from: try await get(url))
        return response.docs.compactMap { doc in
            guard let title = doc.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else { return nil }
            return BookMetadata(
                title: title,
                author: (doc.author_name ?? []).joined(separator: ", "),
                isbn: Self.bestISBN(from: doc.isbn ?? []),
                coverURL: doc.cover_i.flatMap {
                    URL(string: "https://covers.openlibrary.org/b/id/\($0)-L.jpg?default=false")
                },
                pageCount: doc.number_of_pages_median,
                description: nil,
                openLibraryWorkKey: doc.key
            )
        }
    }

    // MARK: Google Books

    private func searchGoogleBooks(_ query: BookQuery) async throws -> [BookMetadata] {
        let q: String
        if let isbn = query.isbn {
            q = "isbn:\(isbn)"
        } else if let text = query.text {
            q = text
        } else {
            q = [query.title.map { "intitle:\($0)" }, query.author.map { "inauthor:\($0)" }]
                .compactMap { $0 }.joined(separator: " ")
        }
        let url = makeURL(googleBooksBase, path: "books/v1/volumes", items: [("q", q), ("maxResults", "10")])
        let response = try JSONDecoder().decode(GBResponse.self, from: try await get(url))
        return (response.items ?? []).compactMap { item in
            let info = item.volumeInfo
            guard let title = info.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else { return nil }
            let identifiers = (info.industryIdentifiers ?? []).map(\.identifier)
            return BookMetadata(
                title: title,
                author: (info.authors ?? []).joined(separator: ", "),
                isbn: Self.bestISBN(from: identifiers),
                coverURL: Self.googleCoverURL(info.imageLinks?.thumbnail ?? info.imageLinks?.smallThumbnail),
                pageCount: info.pageCount.flatMap { $0 > 0 ? $0 : nil },
                description: info.description?.trimmingCharacters(in: .whitespacesAndNewlines),
                openLibraryWorkKey: nil
            )
        }
    }

    // MARK: Helpers

    private func get(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("Shelfie/0.1 (personal TBR app)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await http.send(request)
        guard (200..<300).contains(response.statusCode) else { throw LookupError.badStatus(response.statusCode) }
        return data
    }

    private func makeURL(_ base: URL, path: String, items: [(String, String)]) -> URL {
        var components = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.percentEncodedQuery = items.map { "\($0.0)=\(Self.encode($0.1))" }.joined(separator: "&")
        return components.url!
    }

    private static let queryValueAllowed: CharacterSet = {
        var set = CharacterSet.urlQueryAllowed
        set.remove(charactersIn: "&=+#")
        return set
    }()

    private static func encode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: queryValueAllowed) ?? value
    }

    /// Prefers a valid ISBN-13; converts a lone ISBN-10.
    private static func bestISBN(from candidates: [String]) -> String? {
        let canonical = candidates.compactMap(ISBN.canonical13)
        return canonical.first
    }

    private static func googleCoverURL(_ raw: String?) -> URL? {
        guard var string = raw else { return nil }
        if string.hasPrefix("http://") { string = "https://" + string.dropFirst("http://".count) }
        string = string.replacingOccurrences(of: "&edge=curl", with: "")
        return URL(string: string)
    }
}

// MARK: Wire formats

private struct OLSearchResponse: Decodable {
    let docs: [OLDoc]
}

private struct OLDoc: Decodable {
    let key: String?
    let title: String?
    let author_name: [String]?
    let isbn: [String]?
    let cover_i: Int?
    let number_of_pages_median: Int?
}

private struct OLWork: Decodable {
    let description: OLText?
}

/// Open Library descriptions are either a plain string or {"type": ..., "value": ...}.
private struct OLText: Decodable {
    let value: String

    private struct Typed: Decodable { let value: String }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let plain = try? container.decode(String.self) {
            value = plain
        } else {
            value = try container.decode(Typed.self).value
        }
    }
}

private struct GBResponse: Decodable {
    let items: [GBItem]?
}

private struct GBItem: Decodable {
    let volumeInfo: GBVolume
}

private struct GBVolume: Decodable {
    let title: String?
    let authors: [String]?
    let description: String?
    let pageCount: Int?
    let industryIdentifiers: [GBIdentifier]?
    let imageLinks: GBImageLinks?
}

private struct GBIdentifier: Decodable {
    let type: String
    let identifier: String
}

private struct GBImageLinks: Decodable {
    let thumbnail: String?
    let smallThumbnail: String?
}
