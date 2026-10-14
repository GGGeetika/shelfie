import SwiftUI

struct SearchTitleView: View {
    private enum SearchState {
        case idle, loading, results([BookMetadata]), empty, failed
    }

    @State private var query = ""
    @State private var state: SearchState = .idle
    @State private var selected: BookMetadata?
    @State private var addedIDs: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            TextField("Title or author", text: $query)
                .font(Theme.Fonts.ui(17))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .padding(12)
                .background(Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.Colors.ink.opacity(0.15)))
                .padding(16)
            content
        }
        .foregroundStyle(Theme.Colors.ink)
        .background(Theme.Colors.cream.ignoresSafeArea())
        .navigationTitle("Search a title")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: query) { await runSearch() }
        .sheet(item: $selected) { book in
            AddBookSheet(book: book) { addedIDs.insert(book.id) }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .idle:
            message("Search for a book to add it to your shelf.")
        case .loading:
            ProgressView().padding(.top, 40)
            Spacer()
        case .empty:
            message("No books found. Try fewer words, or just the title.")
        case .failed:
            message("Couldn't reach the book databases. Check your connection and try again.")
        case .results(let books):
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(books) { book in
                        Button { selected = book } label: { row(book) }
                            .buttonStyle(.plain)
                        Divider()
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func message(_ text: String) -> some View {
        VStack {
            Text(text)
                .font(Theme.Fonts.ui(15))
                .opacity(0.7)
                .multilineTextAlignment(.center)
                .padding(.top, 40)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    private func row(_ book: BookMetadata) -> some View {
        HStack(spacing: 14) {
            CoverView(url: book.coverURL, title: book.title).frame(width: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text(book.title).font(Theme.Fonts.title(17)).multilineTextAlignment(.leading)
                if !book.author.isEmpty {
                    Text(book.author).font(Theme.Fonts.ui(14)).opacity(0.75)
                }
                if let pages = book.pageCount {
                    Text("\(pages) pages").font(Theme.Fonts.ui(12)).opacity(0.55)
                }
            }
            Spacer()
            Image(systemName: addedIDs.contains(book.id) ? "checkmark.circle.fill" : "plus.circle")
                .font(.title2)
                .foregroundStyle(Theme.Colors.brick)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func runSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            state = .idle
            return
        }
        // Debounce: typing again cancels this task during the sleep.
        try? await Task.sleep(nanoseconds: 400_000_000)
        guard !Task.isCancelled else { return }
        state = .loading
        do {
            let books = try await BookLookup.live.search(.text(trimmed))
            guard !Task.isCancelled else { return }
            state = books.isEmpty ? .empty : .results(books)
        } catch {
            guard !Task.isCancelled else { return }
            state = .failed
        }
    }
}
