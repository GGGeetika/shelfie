import Foundation
import SwiftData

@Model
final class Club {
    var id: UUID = UUID()
    var name: String

    @Relationship(inverse: \Recommendation.club)
    var recommendations: [Recommendation] = []

    init(name: String) {
        self.name = name
    }
}
