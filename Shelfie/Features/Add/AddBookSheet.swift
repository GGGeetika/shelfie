import SwiftUI

/// Confirms a lookup result: who it came from, an optional note, then adds it.
struct AddBookSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var book: BookMetadata
    @State private var source: SourceType = .friend
    @State private var sourceName = ""
    @State private var note = ""
    @State private var errorMessage: String?

    private let onAdded: () -> Void

    init(book: BookMetadata, onAdded: @escaping () -> Void) {
        _book = State(initialValue: book)
        self.onAdded = onAdded
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Where did you hear about it?")
                            .font(Theme.Fonts.ui(14).weight(.semibold))
                        Picker("Source", selection: $source) {
                            ForEach(SourceType.manualCases) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                    if source != .me {
                        field(source == .friend ? "Friend's name (optional)" : "Club name (optional)", text: $sourceName)
                    }
                    field("Note (optional)", text: $note, axis: .vertical)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(Theme.Fonts.ui(14))
                            .foregroundStyle(Theme.Colors.brick)
                    }

                    Button(action: save) {
                        Text("Add to my shelf")
                            .font(Theme.Fonts.ui(17).weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(Theme.Colors.cream)
                            .background(Theme.Colors.brick, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(20)
            }
            .background(Theme.Colors.cream.ignoresSafeArea())
            .foregroundStyle(Theme.Colors.ink)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .presentationDetents([.large])
        .task { book = await BookLookup.live.details(for: book) }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            CoverView(url: book.coverURL, title: book.title)
                .frame(width: 110)
            VStack(alignment: .leading, spacing: 6) {
                Text(book.title).font(Theme.Fonts.title(22))
                if !book.author.isEmpty {
                    Text(book.author).font(Theme.Fonts.ui(15)).opacity(0.8)
                }
                if let pages = book.pageCount {
                    Text("\(pages) pages").font(Theme.Fonts.ui(13)).opacity(0.65)
                }
                if let description = book.description {
                    Text(description)
                        .font(Theme.Fonts.ui(13))
                        .opacity(0.75)
                        .lineLimit(4)
                }
            }
        }
    }

    private func field(_ title: String, text: Binding<String>, axis: Axis = .horizontal) -> some View {
        TextField(title, text: text, axis: axis)
            .font(Theme.Fonts.ui(16))
            .lineLimit(axis == .vertical ? 3...6 : 1...1)
            .padding(12)
            .background(Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.Colors.ink.opacity(0.15)))
    }

    private func save() {
        do {
            try LibraryService(context: context).add(book, source: source, sourceName: sourceName, note: note)
            onAdded()
            dismiss()
        } catch {
            errorMessage = "Couldn't save this book. Please try again."
        }
    }
}
