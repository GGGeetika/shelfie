import SwiftUI

enum ShelfieTab: String, CaseIterable, Identifiable {
    case shelf = "Shelf"
    case add = "Add"
    case next = "Next"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .shelf: "books.vertical"
        case .add: "plus.square"
        case .next: "book"
        }
    }
}

struct RootTabView: View {
    var body: some View {
        TabView {
            ShelfView()
                .tabItem { Label(ShelfieTab.shelf.rawValue, systemImage: ShelfieTab.shelf.systemImage) }
            AddView()
                .tabItem { Label(ShelfieTab.add.rawValue, systemImage: ShelfieTab.add.systemImage) }
            NextView()
                .tabItem { Label(ShelfieTab.next.rawValue, systemImage: ShelfieTab.next.systemImage) }
        }
        .tint(Theme.Colors.brick)
        .toolbarBackground(Theme.Colors.cream, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}

#Preview { RootTabView() }
