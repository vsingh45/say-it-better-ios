import SwiftUI
import SwiftData

struct AllWordsView: View {
    @Environment(WordStore.self) private var store
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HeardWord.date, order: .reverse) private var heard: [HeardWord]
    @State private var deepDiveWord: Word?

    private var trimmedQuery: String {
        store.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }


    private var results: [Word] {
        let query = store.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return store.filteredWords }
        return store.filteredWords.filter {
            $0.word.localizedCaseInsensitiveContains(query)
                || $0.definition.localizedCaseInsensitiveContains(query)
                || $0.insteadOf.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if trimmedQuery.isEmpty, !heard.isEmpty {
                    Section {
                        NavigationLink {
                            HeardWordsView()
                        } label: {
                            HStack {
                                Label("Heard & read", systemImage: "ear")
                                Spacer()
                                Text("\(heard.count) saved")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section {
                    if results.isEmpty, !trimmedQuery.isEmpty {
                        Text("No match in your word list. Press search to save it under Heard & read.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(results) { word in
                        AllWordRow(
                            word: word,
                            isKnown: Binding(
                                get: { store.isKnown(word) },
                                set: { store.setKnown($0, for: word) }
                            ),
                            onDeepDive: { deepDiveWord = word }
                        )
                    }
                } header: {
                    CategoryChips()
                        .padding(.horizontal, -16)
                        .textCase(nil)
                } footer: {
                    Text("\(results.count) word\(results.count == 1 ? "" : "s")")
                        .font(Theme.monoSmall)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("All words")
            .settingsToolbar()
            .heardSearch()
            .sheet(item: $deepDiveWord) { DeepDiveSheet(word: $0) }
        }
    }
}

private struct AllWordRow: View {
    let word: Word
    @Binding var isKnown: Bool
    let onDeepDive: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(word.word)
                        .font(Theme.serif(.headline))
                    Text(word.partOfSpeech)
                        .font(Theme.monoSmall)
                        .foregroundStyle(.secondary)
                }
                Text(word.definition)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Button("Deep dive", systemImage: "text.magnifyingglass", action: onDeepDive)
                    .font(.footnote)
                    .buttonStyle(.borderless)
            }
            Spacer(minLength: 8)
            VStack(spacing: 2) {
                Toggle("Known", isOn: $isKnown)
                    .labelsHidden()
                Text(isKnown ? "KNOWN" : "LEARNING")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(isKnown ? Color.accentColor : .secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    AllWordsView()
        .environment(WordStore())
        .environment(DeepDiveService())
}
