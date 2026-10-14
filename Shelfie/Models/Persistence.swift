import SwiftData

enum Persistence {
    static let models: [any PersistentModel.Type] = [
        Book.self, Recommendation.self, Photo.self, Club.self, Shelf.self, ShelfBook.self,
    ]

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
