import SwiftUI
import SwiftData

/// Every word the user has heard or read and saved, filtered by category so the list stays manageable as it grows.
struct HeardWordsView: View {
    @Environment(WordStore.self) private var store
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HeardWord.date, order: .reverse) private var heard: [HeardWord]

    @State private var category: String?
    @State private var openCard: Word?

    /// Categories that have saved words, in the order they appear in the word list, with "Searched" last.
    private var categories: [String] {
        let present = Set(heard.map(\.category))
        return store.categories.filter(present.contains) + (present.contains("Searched") ? ["Searched"] : [])
    }

    private var shown: [HeardWord] {
        guard let category else { return heard }
        return heard.filter { $0.category == category }
    }

    var body: some View {
        List {
            if !categories.isEmpty {
                Section {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            chip("All", value: nil)
                            ForEach(categories, id: \.self) { name in
                                chip(name, value: name)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .scrollIndicators(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    .listRowBackground(Color.clear)
                }
            }

            Section {
                if shown.isEmpty {
                    Text(heard.isEmpty ? "Words you search and look up show up here." : "No saved words in this category.")
                        .foregroundStyle(.secondary)
                }
                ForEach(shown) { item in
                    Button {
                        openCard = card(for: item)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.term).font(Theme.serif(.headline))
                                Spacer()
                                Text(item.category)
                                    .font(Theme.monoSmall)
                                    .foregroundStyle(.secondary)
                            }
                            Text(card(for: item)?.definition ?? "No card saved for this word yet")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                    .disabled(card(for: item) == nil)
                }
                .onDelete(perform: delete)
            } header: {
                Text("\(shown.count) saved")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Heard & read")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $openCard) { SearchedWordCard(word: $0) }
    }

    /// The card saved with the term, or the word's card from the app's list.
    private func card(for item: HeardWord) -> Word? {
        item.card ?? store.words.first { $0.word.caseInsensitiveCompare(item.term) == .orderedSame }
    }

    private func chip(_ title: String, value: String?) -> some View {
        let selected = category == value
        return Button {
            category = value
        } label: {
            Text(title)
                .font(Theme.mono)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selected ? Color.accentColor : Color(.secondarySystemBackground), in: Capsule())
                .foregroundStyle(selected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(shown[index])
        }
        try? modelContext.save()
    }
}
