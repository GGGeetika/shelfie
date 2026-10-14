import SwiftData
import SwiftUI

/// Temporary plain list so added books are visible; replaced by the real shelf in Stage 3.
struct ShelfView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Book.addedAt, order: .reverse) private var books: [Book]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Your Shelfie")
                    .font(Theme.Fonts.display(34))
                BrickDivider()
                if books.isEmpty {
                    Text("Nothing here yet. Add a book from the Add tab.")
                        .font(Theme.Fonts.ui(16))
                        .opacity(0.75)
                    Spacer()
                } else {
                    List {
                        ForEach(books) { book in
                            HStack(spacing: 14) {
                                CoverView(url: book.coverURL, title: book.title).frame(width: 48)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(book.title).font(Theme.Fonts.title(17))
                                    Text(book.author).font(Theme.Fonts.ui(14)).opacity(0.75)
                                    Text(summary(for: book)).font(Theme.Fonts.ui(12)).opacity(0.55)
                                }
                            }
                            .listRowBackground(Color.clear)
                        }
                        .onDelete { offsets in
                            offsets.map { books[$0] }.forEach(context.delete)
                            try? context.save()
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .foregroundStyle(Theme.Colors.ink)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.Colors.cream.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func summary(for book: Book) -> String {
        let sources = Set(book.recommendations.map { $0.sourceType.label.lowercased() })
        let list = sources.sorted().joined(separator: ", ")
        return list.isEmpty ? "No source" : "From: \(list)"
    }
}
