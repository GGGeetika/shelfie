import SwiftData
import SwiftUI

@main
struct ShelfieApp: App {
    private let container: ModelContainer = {
        do {
            return try Persistence.makeContainer()
        } catch {
            fatalError("Could not open the Shelfie database: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(container)
    }
}
