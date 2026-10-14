import Foundation

enum BookStatus: String, CaseIterable, Identifiable {
    case wantToRead, upNext, reading, notForMe

    var id: String { rawValue }

    var label: String {
        switch self {
        case .wantToRead: "Want to read"
        case .upNext: "Up next"
        case .reading: "Reading"
        case .notForMe: "Not for me"
        }
    }
}

enum SourceType: String, CaseIterable, Identifiable {
    case friend, club, me, photo, screenshot

    var id: String { rawValue }

    var label: String {
        switch self {
        case .friend: "Friend"
        case .club: "Club"
        case .me: "Me"
        case .photo: "Photo"
        case .screenshot: "Screenshot"
        }
    }

    /// Sources I can pick by hand when adding a book.
    static let manualCases: [SourceType] = [.friend, .club, .me]
}
