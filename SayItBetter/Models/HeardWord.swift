import Foundation
import SwiftData

/// A word or phrase the user heard or read somewhere and wants to remember, whether or not it is in `words.json`.
/// Searched terms keep the card the agent wrote, so it can be opened again later.
@Model
final class HeardWord {
    @Attribute(.unique) var term: String
    var date: Date
    /// The word's category in the app's list, or "Searched" for terms that are not in it.
    var category: String = "Searched"
    var pronunciation: String = ""
    var partOfSpeech: String = ""
    var definition: String = ""
    var example: String = ""
    var insteadOf: String = ""
    var goesWith: [String] = []

    init(term: String, category: String = "Searched", date: Date = .now) {
        self.term = term
        self.category = category
        self.date = date
    }

    /// Copies a card's fields onto this saved word.
    func store(_ word: Word) {
        pronunciation = word.pronunciation
        partOfSpeech = word.partOfSpeech
        definition = word.definition
        example = word.example
        insteadOf = word.insteadOf
        goesWith = word.goesWith
    }

    /// The saved card, or nil for a term that was saved without one.
    var card: Word? {
        guard !definition.isEmpty else { return nil }
        return Word(word: term, pronunciation: pronunciation, partOfSpeech: partOfSpeech, category: category,
                    definition: definition, example: example, insteadOf: insteadOf, goesWith: goesWith)
    }

    /// The category to file a saved term under: its own category if it is in the list, otherwise "Searched".
    static func category(for term: String, in words: [Word]) -> String {
        words.first { $0.word.caseInsensitiveCompare(term) == .orderedSame }?.category ?? "Searched"
    }
}
