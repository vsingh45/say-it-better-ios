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

@available(iOS 26.0, *)
@Generable
struct GeneratedFamilyMember {
    @Guide(description: "A related word, such as another form of the same root")
    var word: String

    @Guide(description: "What the related word means, in a few words")
    var meaning: String
}

@available(iOS 26.0, *)
@Generable
struct GeneratedComparison {
    @Guide(description: "A close word that is often confused with the main word")
    var word: String

    @Guide(description: "How the close word differs from the main word, in one sentence")
    var difference: String
}

@available(iOS 26.0, *)
@Generable
struct GeneratedExample {
    @Guide(description: "The workplace setting, e.g. Standup, Design review, Incident call, Stakeholder update, 1:1, Email")
    var setting: String

    @Guide(description: "One natural sentence in that setting that uses the word")
    var sentence: String
}

/// The in-depth explanation the Go deeper sheet shows, written on the iPhone.
@available(iOS 26.0, *)
@Generable
struct GeneratedDeepDive {
    @Guide(description: "A simple respelling with the stressed syllable in capitals")
    var pronunciation: String

    @Guide(description: "One short label such as noun, verb or adjective")
    var partOfSpeech: String

    @Guide(description: "A clear meaning in one or two sentences")
    var meaning: String

    @Guide(description: "Where the word comes from, if known. Say so if uncertain.")
    var origin: String

    @Guide(description: "Two to four related words from the same root")
    var family: [GeneratedFamilyMember]

    @Guide(description: "Three or four short phrases the word is commonly used with")
    var collocations: [String]

    @Guide(description: "One or two close words that are often confused with it")
    var compare: [GeneratedComparison]

    @Guide(description: "A common mistake people make with this word, in one or two sentences")
    var mistake: String

    @Guide(description: "Exactly one example for each setting, in this order: Standup, Design review, Incident call, Stakeholder update, 1:1, Email")
    var examples: [GeneratedExample]

    @Guide(description: "One practical tip for using the word well at work")
    var tip: String
}

@available(iOS 26.0, *)
@Generable
struct GeneratedFeedback {
    @Guide(description: "Exactly one of: good, almost, off")
    var verdict: String

    @Guide(description: "One or two encouraging, specific sentences about how the word was used")
    var feedback: String

    @Guide(description: "A polished version of the sentence that keeps its meaning and uses the word")
    var improved: String
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

    /// The Go deeper explanation for a word, written on the iPhone.
    static func deepDive(for term: String) async throws -> DeepDive {
        guard #available(iOS 26.0, *) else { throw LookupError.needsNewerIOS }
        guard SystemLanguageModel.default.availability == .available else { throw LookupError.unavailable }

        let session = LanguageModelSession(instructions: """
            You are a vocabulary coach for a lead software engineer who wants to sound clear and confident \
            when presenting and explaining technical work to teams and stakeholders. \
            Be accurate about etymology and say so when it is uncertain.
            """)
        let response = try await session.respond(
            to: "Explain the English word or phrase \"\(term)\" in depth for a workplace vocabulary card.",
            generating: GeneratedDeepDive.self
        )
        let content = response.content
        return DeepDive(
            word: term,
            pronunciation: content.pronunciation,
            partOfSpeech: content.partOfSpeech,
            meaning: content.meaning,
            origin: content.origin,
            family: content.family.map { DeepDive.FamilyMember(word: $0.word, meaning: $0.meaning) },
            collocations: content.collocations,
            compare: content.compare.map { DeepDive.Comparison(word: $0.word, difference: $0.difference) },
            mistake: content.mistake,
            examples: content.examples.map { DeepDive.Example(setting: $0.setting, sentence: $0.sentence) },
            tip: content.tip
        )
    }

    /// Judges a sentence the user wrote with the word, written on the iPhone.
    static func checkSentence(_ sentence: String, word: String) async throws -> SentenceFeedback {
        guard #available(iOS 26.0, *) else { throw LookupError.needsNewerIOS }
        guard SystemLanguageModel.default.availability == .available else { throw LookupError.unavailable }

        let session = LanguageModelSession(instructions: """
            You are a vocabulary coach for a lead software engineer who wants to sound clear and confident \
            when presenting and explaining technical work to teams and stakeholders. \
            Judge whether the word is used correctly and naturally for a workplace setting.
            """)
        let response = try await session.respond(
            to: "They wrote this sentence to practise the word \"\(word)\":\n\n\(sentence)",
            generating: GeneratedFeedback.self
        )
        let content = response.content
        return SentenceFeedback(verdict: content.verdict, feedback: content.feedback, improved: content.improved)
    }
}
