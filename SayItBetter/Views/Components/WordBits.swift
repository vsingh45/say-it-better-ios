import SwiftUI
import SwiftData

/// The example sentence with the `[target]` span emphasised in the accent colour.
struct HighlightedExample: View {
    let word: Word
    var font: Font = .body

    var body: some View {
        Text(attributed)
            .font(font)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var attributed: AttributedString {
        word.exampleSegments.reduce(into: AttributedString()) { result, segment in
            var piece = AttributedString(segment.text)
            if segment.emphasised {
                piece.inlinePresentationIntent = .stronglyEmphasized
                piece[AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self] = Color.accentColor
                piece[AttributeScopes.SwiftUIAttributes.BackgroundColorAttribute.self] = Color.accentColor.opacity(0.12)
            }
            result += piece
        }
    }
}

/// "Instead of saying '…', say *word*."
struct InsteadOfSwap: View {
    let word: Word

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "arrow.triangle.swap")
                .foregroundStyle(Color.accentColor)
            (Text("Instead of saying ")
                + Text("“\(word.insteadOf)”").italic()
                + Text(", say ")
                + Text(word.word).bold().foregroundColor(.accentColor)
                + Text("."))
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Speaker button that reads the word aloud.
struct HearItButton: View {
    let text: String

    var body: some View {
        Button {
            Speaker.shared.speak(text)
        } label: {
            Image(systemName: "speaker.wave.2.fill")
                .font(.title3)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.1), in: Circle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Hear \(text)")
    }
}

/// Category · part of speech, in mono.
struct WordMeta: View {
    let word: Word

    var body: some View {
        Text("\(word.category.uppercased()) · \(word.partOfSpeech)")
            .font(Theme.monoSmall)
            .foregroundStyle(.secondary)
    }
}

/// Horizontally scrolling filter chips shared by Learn, Quiz and All words.
struct CategoryChips: View {
    @Environment(WordStore.self) private var store

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All", value: nil)
                ForEach(store.categories, id: \.self) { category in
                    chip(category, value: category)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }

    private func chip(_ title: String, value: String?) -> some View {
        let selected = store.categoryFilter == value
        return Button {
            store.categoryFilter = value
        } label: {
            Text(title)
                .font(Theme.mono)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(selected ? Color.white : Color.primary)
                .background(
                    Capsule().fill(selected ? Color.accentColor : Theme.surface)
                )
                .overlay(Capsule().strokeBorder(selected ? Color.clear : Theme.hairline, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Toolbar gear that opens Settings; added to every tab.
struct SettingsToolbar: ViewModifier {
    @State private var showingSettings = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
    }
}

extension View {
    func settingsToolbar() -> some View { modifier(SettingsToolbar()) }
    func heardSearch() -> some View { modifier(HeardSearch()) }
}

/// The search bar at the top of every tab. Results appear below it; saving a term adds it to "Heard & read".
struct HeardSearch: ViewModifier {
    @Environment(WordStore.self) private var store

    func body(content: Content) -> some View {
        @Bindable var store = store
        content
            .searchable(text: $store.searchText, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "A word you heard or read")
            .overlay(alignment: .top) {
                if !store.searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                    SearchResultsPanel(query: store.searchText.trimmingCharacters(in: .whitespaces))
                }
            }
    }
}

/// Matching words from the list, an "ask the agent" row for any word, and a row to save whatever was typed.
private struct SearchResultsPanel: View {
    let query: String

    @Environment(WordStore.self) private var store
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HeardWord.date, order: .reverse) private var heard: [HeardWord]

    @State private var lookingUp = false
    @State private var lookupError: String?
    @State private var card: Word?

    private var matches: [Word] {
        store.words.filter {
            $0.word.localizedCaseInsensitiveContains(query) || $0.definition.localizedCaseInsensitiveContains(query)
        }
        .prefix(10).map { $0 }
    }

    private func isSaved(_ term: String) -> Bool {
        heard.contains { $0.term.caseInsensitiveCompare(term) == .orderedSame }
    }

    private func save(_ term: String) {
        guard !isSaved(term) else { return }
        modelContext.insert(HeardWord(term: term, category: HeardWord.category(for: term, in: store.words)))
        try? modelContext.save()
    }

    /// Saves the term with its card, updating the card if the term was already saved.
    private func saveCard(_ word: Word) {
        if let existing = heard.first(where: { $0.term.caseInsensitiveCompare(query) == .orderedSame }) {
            existing.store(word)
        } else {
            let item = HeardWord(term: query, category: HeardWord.category(for: query, in: store.words))
            item.store(word)
            modelContext.insert(item)
        }
        try? modelContext.save()
    }

    /// Asks the agent for a card, shows it, and saves the term with its card under "Heard & read".
    private func lookUp() {
        lookingUp = true
        lookupError = nil
        Task {
            do {
                let word = try await OnDeviceLookup.lookup(query)
                saveCard(word)
                card = word
            } catch {
                lookupError = error.localizedDescription
            }
            lookingUp = false
        }
    }

    var body: some View {
        List {
            Section {
                Button {
                    lookUp()
                } label: {
                    HStack {
                        Label("Get a card for “\(query)”", systemImage: "sparkles")
                        Spacer()
                        if lookingUp { ProgressView() }
                    }
                }
                .disabled(lookingUp)
                if let lookupError {
                    Text(lookupError)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Ask the agent")
            }

            Section {
                ForEach(matches) { word in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(word.word).font(Theme.serif(.headline))
                        Text(word.definition)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                if matches.isEmpty {
                    Text("No match in your word list.")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Results for “\(query)”")
            }
        }
        .listStyle(.insetGrouped)
        .background(Theme.background)
        .sheet(item: $card) { SearchedWordCard(word: $0) }
    }
}

/// A searched word shown the same way as a Feed word card.
struct SearchedWordCard: View {
    let word: Word
    @State private var session = FeedSession()

    var body: some View {
        NavigationStack {
            FeedPage(kind: .wordCard) {
                WordCardPost(word: word, session: session)
            }
            .navigationTitle("Searched word")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDragIndicator(.visible)
    }
}
