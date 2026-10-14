import Foundation
import SwiftData

@Model
final class Recommendation {
    var id: UUID = UUID()
    var sourceTypeRaw: String
    /// Who sent it, for friend recommendations.
    var friendName: String?
    var note: String?
    var createdAt: Date = Date.now

    var book: Book?
    var club: Club?
    var photo: Photo?

    init(sourceType: SourceType, friendName: String? = nil, note: String? = nil, createdAt: Date = .now) {
        self.sourceTypeRaw = sourceType.rawValue
        self.friendName = friendName
        self.note = note
        self.createdAt = createdAt
    }

    var sourceType: SourceType {
        get { SourceType(rawValue: sourceTypeRaw) ?? .me }
        set { sourceTypeRaw = newValue.rawValue }
    }
}
