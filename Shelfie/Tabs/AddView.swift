import SwiftUI

struct AddView: View {
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Add")
                    .font(Theme.Fonts.display(34))
                BrickDivider()
                NavigationLink {
                    SearchTitleView()
                } label: {
                    AddRow(title: "Search a title", subtitle: "Find a book by title or author", systemImage: "magnifyingglass")
                }
                NavigationLink {
                    ScanBarcodeView()
                } label: {
                    AddRow(title: "Scan a barcode", subtitle: "Read the ISBN on the back cover", systemImage: "barcode.viewfinder")
                }
                Spacer()
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.Colors.ink)
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.Colors.cream.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct AddRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(Theme.Colors.brick)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.Fonts.title(19))
                Text(subtitle).font(Theme.Fonts.ui(14)).opacity(0.7)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Theme.Colors.brick)
        }
        .padding(16)
        .background(Color.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.ink.opacity(0.12)))
    }
}
