import Foundation
import SwiftData

/// A shelf I create myself.
@Model
final class Shelf {
    var id: UUID = UUID()
    var name: String
    var createdAt: Date = Date.now
    var sortIndex: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \ShelfBook.shelf)
    var shelfBooks: [ShelfBook] = []

    init(name: String, sortIndex: Int = 0, createdAt: Date = .now) {
        self.name = name
        self.sortIndex = sortIndex
        self.createdAt = createdAt
    }
}
