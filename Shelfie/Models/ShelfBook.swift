import Foundation
import SwiftData

/// A book's place on one of my shelves; `order` keeps the arrangement I chose.
@Model
final class ShelfBook {
    var id: UUID = UUID()
    var order: Int = 0

    var shelf: Shelf?
    var book: Book?

    init(shelf: Shelf? = nil, book: Book? = nil, order: Int = 0) {
        self.shelf = shelf
        self.book = book
        self.order = order
    }
}
