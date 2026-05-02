import SwiftUI

// Bottom-sheet kaomoji picker with search + categories — translation of
// KaomojiPicker in chat.jsx. Catalogue is loaded from Resources/Kaomoji.json.

struct KaomojiCatalogue: Decodable {
    struct Category: Decodable, Identifiable {
        let id: String
        let label_zh: String
        let label_en: String
        let label_ja: String
        let entries: [String]

        var label: String { label_zh }
    }

    let version: Int
    let quick_react: [String]
    let categories: [Category]

    static let bundled: KaomojiCatalogue = {
        guard let url = Bundle.main.url(forResource: "Kaomoji", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let parsed = try? JSONDecoder().decode(KaomojiCatalogue.self, from: data)
        else { return KaomojiCatalogue(version: 0, quick_react: [], categories: []) }
        return parsed
    }()
}

struct KaomojiPicker: View {
    @Environment(\.theme) private var theme

    let onPick: (String) -> Void
    let onClose: () -> Void

    @State private var query: String = ""
    @State private var selectedCategory: String = "love"

    private let catalogue = KaomojiCatalogue.bundled

    var body: some View {
        VStack(spacing: 0) {
            searchRow
            grid
            categoryStrip
        }
        .background(theme.surface)
        .overlay(
            Rectangle().frame(height: 0.5).foregroundStyle(theme.line),
            alignment: .top
        )
        .frame(maxHeight: 290)
    }

    private var searchRow: some View {
        HStack(spacing: 8) {
            DSIcon(name: .search, size: 14, color: theme.inkMuted)
            TextField("搜尋顏文字…", text: $query)
                .font(DSText.ui(theme, 13))
                .foregroundStyle(theme.ink)
            Button(action: onClose) {
                DSIcon(name: .close, size: 16, color: theme.inkMuted)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Rectangle().frame(height: 0.5).foregroundStyle(theme.line),
            alignment: .bottom
        )
    }

    private var grid: some View {
        let entries = visibleEntries
        return ScrollView {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 6),
                                GridItem(.flexible(), spacing: 6),
                                GridItem(.flexible(), spacing: 6)], spacing: 6) {
                ForEach(entries.indices, id: \.self) { i in
                    Button {
                        onPick(entries[i])
                    } label: {
                        Text(entries[i])
                            .font(DSText.mono(theme, 13))
                            .foregroundStyle(theme.ink)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .padding(.vertical, 6)
                            .background(theme.paperAlt)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
        }
    }

    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                DSChip(label: "最近",
                       active: selectedCategory == "recent",
                       color: theme.rose) {
                    selectedCategory = "recent"; query = ""
                }
                ForEach(catalogue.categories) { c in
                    DSChip(label: c.label,
                           active: selectedCategory == c.id,
                           color: theme.rose) {
                        selectedCategory = c.id; query = ""
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .overlay(
            Rectangle().frame(height: 0.5).foregroundStyle(theme.line),
            alignment: .top
        )
    }

    private var visibleEntries: [String] {
        if !query.isEmpty {
            return catalogue.categories
                .flatMap(\.entries)
                .filter { $0.localizedCaseInsensitiveContains(query) }
        }
        if selectedCategory == "recent" {
            return catalogue.quick_react
        }
        return catalogue.categories.first { $0.id == selectedCategory }?.entries ?? []
    }
}
