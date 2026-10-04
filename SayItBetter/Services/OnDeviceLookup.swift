import Foundation
import FoundationModels

/// The card the on-device model writes for a searched word.
@available(iOS 26.0, *)
@Generable
struct GeneratedWordCard {
    @Guide(description: "A simple respelling with the stressed syllable in capitals, e.g. rek-uhn-sil-ee-AY-shun")
    var pronunciation: String

    @Guide(description: "One short label such as noun, verb or adjective")
    var partOfSpeech: String

    @Guide(description: "One plain sentence explaining the word")
    var definition: String

    @Guide(description: "One natural workplace sentence that uses the word, with the word wrapped in square brackets")
    var example: String

    @Guide(description: "A plainer phrase a person would otherwise say instead")
    var insteadOf: String

    @Guide(description: "Exactly three short phrases the word is commonly used with")
    var goesWith: [String]
}

/// Looks up any word on the iPhone itself, with Apple's on-device model. No network or Mac needed.
enum OnDeviceLookup {
    enum LookupError: LocalizedError {
        case needsNewerIOS
        case unavailable

        var errorDescription: String? {
            switch self {
            case .needsNewerIOS:
                return "Word lookup needs iOS 26 or later."
            case .unavailable:
                return "Word lookup needs Apple Intelligence on this iPhone. Turn it on in Settings › Apple Intelligence & Siri."
            }
        }
    }

    /// True when this iPhone can run the on-device model right now.
    static var isAvailable: Bool {
        guard #available(iOS 26.0, *) else { return false }
        return SystemLanguageModel.default.availability == .available
    }

    static func lookup(_ term: String) async throws -> Word {
        guard #available(iOS 26.0, *) else { throw LookupError.needsNewerIOS }
        guard SystemLanguageModel.default.availability == .available else { throw LookupError.unavailable }

        let session = LanguageModelSession(instructions: """
            You are a vocabulary coach for a lead software engineer who wants to sound clear and confident \
            when presenting and explaining technical work to teams and stakeholders. \
            Write short, accurate, plain-English word cards.
            """)
        let response = try await session.respond(
            to: "Write a word card for the English word or phrase \"\(term)\".",
            generating: GeneratedWordCard.self
        )
        let card = response.content
        return Word(word: term, pronunciation: card.pronunciation, partOfSpeech: card.partOfSpeech,
                    category: "Searched", definition: card.definition, example: card.example,
                    insteadOf: card.insteadOf, goesWith: Array(card.goesWith.prefix(3)))
    }
}
