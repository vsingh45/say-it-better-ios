import Foundation
import Observation
import SwiftData

/// Shared app state: every word, which ones are known, and the category filter that the
/// Learn, Quiz and All words tabs share. Known words are stored in SwiftData (`KnownWord`).
@Observable
final class WordStore {
    /// Key the old UserDefaults-based version used, imported once on first launch.
    private static let legacyKey = "knownWords"

    let words: [Word]
    /// Categories in the order they first appear in `words.json`.
    let categories: [String]

    private(set) var known: Set<String>
    /// Searched words the user marked "I know this". They live outside `words`, with the card the agent wrote.
    private(set) var searched: [Word] = []
    /// nil means "All".
    var categoryFilter: String?
    /// The search bar shown at the top of every tab. Submitting it saves the term as heard.
    var searchText = ""

    private let context: ModelContext?

    /// Pass a context to persist known words. Without one (previews, tests) the set lives in memory only.
    init(words: [Word] = WordLoader.load(), context: ModelContext? = nil) {
        self.words = words
        var seen = Set<String>()
        self.categories = words.map(\.category).filter { seen.insert($0).inserted }
        self.context = context
        self.known = []
        if let context {
            self.known = Self.loadKnown(from: context)
            self.searched = Self.loadSearched(from: context, known: known, words: words)
        }
    }

    /// Words in the current category filter.
    var filteredWords: [Word] {
        guard let categoryFilter else { return words }
        return words.filter { $0.category == categoryFilter }
    }

    /// Every known word, A–Z, regardless of the filter. Includes searched words marked "I know this".
    var knownWords: [Word] {
        (words + searched)
            .filter { known.contains($0.word) }
            .sorted { $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending }
    }

    func isKnown(_ word: Word) -> Bool {
        known.contains(word.word)
    }

    func setKnown(_ isKnown: Bool, for word: Word) {
        let inList = words.contains { $0.word == word.word }
        if isKnown {
            if !inList, !searched.contains(where: { $0.word == word.word }) {
                searched.append(word)
            }
            guard known.insert(word.word).inserted else { return }
            if let context {
                context.insert(KnownWord(word: word.word))
            }
        } else {
            if !inList {
                searched.removeAll { $0.word == word.word }
            }
            guard known.remove(word.word) != nil else { return }
            if let context {
                try? context.delete(model: KnownWord.self, where: #Predicate { $0.word == word.word })
            }
        }
        save()
    }

    func resetProgress() {
        known.removeAll()
        searched.removeAll()
        try? context?.delete(model: KnownWord.self)
        save()
    }

    private func save() {
        try? context?.save()
    }

    /// Reads the saved words, and moves any left over from the old UserDefaults storage into SwiftData.
    private static func loadKnown(from context: ModelContext) -> Set<String> {
        var known = Set((try? context.fetch(FetchDescriptor<KnownWord>()))?.map(\.word) ?? [])

        let defaults = UserDefaults.standard
        if let legacy = defaults.stringArray(forKey: legacyKey) {
            for word in legacy where known.insert(word).inserted {
                context.insert(KnownWord(word: word))
            }
            defaults.removeObject(forKey: legacyKey)
            try? context.save()
        }
        return known
    }

    /// Searched words that are marked known, rebuilt from the cards saved with them in "Heard & read".
    private static func loadSearched(from context: ModelContext, known: Set<String>, words: [Word]) -> [Word] {
        let saved = (try? context.fetch(FetchDescriptor<HeardWord>())) ?? []
        return saved
            .filter { entry in known.contains(entry.term) && !words.contains { $0.word == entry.term } }
            .compactMap(\.card)
    }
}
