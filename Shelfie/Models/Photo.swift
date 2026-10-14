import Foundation
import SwiftData

/// A photo or screenshot a book was spotted in. Location stays on the phone.
@Model
final class Photo {
    var id: UUID = UUID()
    /// PhotoKit local identifier, used to show the original from the library.
    var assetLocalIdentifier: String?
    var takenAt: Date?
    var latitude: Double?
    var longitude: Double?
    var placeName: String?
    var isScreenshot: Bool = false

    @Relationship(inverse: \Recommendation.photo)
    var recommendations: [Recommendation] = []

    init(
        assetLocalIdentifier: String? = nil,
        takenAt: Date? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        placeName: String? = nil,
        isScreenshot: Bool = false
    ) {
        self.assetLocalIdentifier = assetLocalIdentifier
        self.takenAt = takenAt
        self.latitude = latitude
        self.longitude = longitude
        self.placeName = placeName
        self.isScreenshot = isScreenshot
    }
}
