import Foundation

/// One full-screen post in the Feed tab.
struct FeedPost: Identifiable, Equatable {
    enum Kind: String, CaseIterable {
        case wordCard
        case swap
        case quiz
        case meeting
        case mistake
        case review
        case dailyDone
    }

    enum Content: Equatable {
        /// Word, pronunciation, meaning and example.
        case wordCard(Word)
        /// "Instead of saying '…'" with a tap-to-reveal of the better word.
        case swap(Word)
        /// The example with the word blanked out and three options.
        case quiz(Word, options: [Word])
        /// A weak and a strong line for the same meeting setting; the strong one uses the word.
        case meeting(Word, setting: String, strong: String, weak: String, strongFirst: Bool)
        /// The deep dive's common mistake and memory tip.
        case mistake(Word, mistake: String, tip: String)
        /// Meaning first, recall the word, then self-grade.
        case review(Word)
        /// "You're done for today" after the daily set.
        case dailyDone
    }

    let id: Int
    let content: Content

    var kind: Kind {
        switch content {
        case .wordCard: .wordCard
        case .swap: .swap
        case .quiz: .quiz
        case .meeting: .meeting
        case .mistake: .mistake
        case .review: .review
        case .dailyDone: .dailyDone
        }
    }

    var word: Word? {
        switch content {
        case .wordCard(let word), .swap(let word), .review(let word): word
        case .quiz(let word, _): word
        case .meeting(let word, _, _, _, _): word
        case .mistake(let word, _, _): word
        case .dailyDone: nil
        }
    }
}

/// Generates an endless, varied stream of feed posts from the word list and the bundled deep dives.
///
/// Rules: never two posts of the same kind in a row, never the same word back to back (and not
/// within the last few posts when the pool allows), unknown words come up far more often than
/// known ones, and kinds that need deep dive data are skipped for words without an entry.
/// Pure value type with a seedable generator, so it can be unit tested deterministically.
struct FeedBuilder {
    static let dailyGoal = 15

    let pool: [Word]
    let allWords: [Word]
    let deepDives: [String: DeepDive]

    private var rng: SplitMix64
    private var nextID: Int
    private(set) var lastKind: FeedPost.Kind?
    /// Most recent last.
    private(set) var recentWords: [String] = []
    /// Every word that has appeared so far, so a review only resurfaces something already seen.
    private(set) var seenWords: Set<String> = []

    /// - Parameters:
    ///   - pool: Words to build posts about (usually the category-filtered list).
    ///   - allWords: Every word, used for quiz distractors.
    ///   - deepDives: Deep dive entries keyed by lowercased word.
    ///   - firstID: The id of the first post, so ids stay unique across rebuilt feeds.
    init(pool: [Word], allWords: [Word], deepDives: [String: DeepDive], firstID: Int = 0, seed: UInt64 = .random(in: .min ... .max)) {
        self.pool = pool
        self.allWords = allWords
        self.deepDives = deepDives
        self.nextID = firstID
        self.rng = SplitMix64(seed: seed)
    }

    // MARK: - Public API

    /// The next `count` posts. `known` is the user's known set; `focus` holds words they recently
    /// struggled with (wrong answer, "Still learning"), which get an extra boost.
    mutating func makeBatch(count: Int, known: Set<String>, focus: Set<String> = []) -> [FeedPost] {
        (0..<count).compactMap { _ in nextPost(known: known, focus: focus) }
    }

    mutating func nextPost(known: Set<String>, focus: Set<String> = []) -> FeedPost? {
        guard let word = pickWord(known: known, focus: focus) else { return nil }
        let kind = pickKind(for: word, known: known, focus: focus)
        guard let content = makeContent(kind, for: word) else {
            // Shouldn't happen (pickKind only offers buildable kinds), but a word card always works.
            return record(.wordCard(word), word: word)
        }
        return record(content, word: word)
    }

    /// The "You're done for today" post. It doesn't count as a kind for the no-repeat rule.
    mutating func makeDailyDonePost() -> FeedPost {
        defer { nextID += 1 }
        return FeedPost(id: nextID, content: .dailyDone)
    }

    /// Which kinds can be built for `word` with the data available.
    func eligibleKinds(for word: Word, known: Set<String>, focus: Set<String> = []) -> [FeedPost.Kind] {
        var kinds: [FeedPost.Kind] = [.wordCard, .swap]
        if allWords.filter({ $0.word != word.word }).count >= 2 { kinds.append(.quiz) }
        if let dive = deepDive(for: word) {
            if !meetingLines(for: word, in: dive).isEmpty { kinds.append(.meeting) }
            if !dive.mistake.isEmpty { kinds.append(.mistake) }
        }
        let isKnown = known.contains(word.word)
        if !isKnown, seenWords.contains(word.word) || focus.contains(word.word) {
            kinds.append(.review)
        }
        return kinds
    }

    /// A vaguer way to say the same thing in `setting`, built from the word's "instead of" phrase.
    static func weakLine(for word: Word, setting: String) -> String {
        let phrase = word.insteadOf
        switch setting {
        case "Standup":
            return "Yesterday I was mostly on the, um, “\(phrase)” thing. Still going."
        case "Design review":
            return "I think we should also think about, like, “\(phrase)” somewhere in here."
        case "Incident call":
            return "So it's basically a “\(phrase)” kind of situation, I think?"
        case "Stakeholder update":
            return "On the “\(phrase)” stuff, it's going okay, more or less."
        case "1:1":
            return "I guess I want to get better at the whole “\(phrase)” thing."
        case "Email":
            return "Quick note on “\(phrase)”. More details at some point."
        default:
            return "So yeah, it's kind of a “\(phrase)” thing."
        }
    }

    // MARK: - Picking

    private func deepDive(for word: Word) -> DeepDive? {
        deepDives[word.word.lowercased()]
    }

    private func meetingLines(for word: Word, in dive: DeepDive) -> [DeepDive.Example] {
        dive.examples.filter { !$0.sentence.isEmpty && word.isUsed(in: $0.sentence) }
    }

    private mutating func pickWord(known: Set<String>, focus: Set<String>) -> Word? {
        guard !pool.isEmpty else { return nil }
        // Keep the last few words out (fewer when the pool is small); never the previous one.
        let avoid = Set(recentWords.suffix(min(4, pool.count - 1)))
        let candidates = pool.filter { !avoid.contains($0.word) }
        return weightedPick(candidates.isEmpty ? pool : candidates) { word in
            if focus.contains(word.word) { return 6 }
            return known.contains(word.word) ? 1 : 4
        }
    }

    private mutating func pickKind(for word: Word, known: Set<String>, focus: Set<String>) -> FeedPost.Kind {
        // Start every feed with a plain word card: the friendliest first screen.
        if lastKind == nil { return .wordCard }

        let isKnown = known.contains(word.word)
        let isNew = !seenWords.contains(word.word)
        var kinds = eligibleKinds(for: word, known: known, focus: focus).filter { $0 != lastKind }
        if kinds.isEmpty { kinds = [lastKind == .wordCard ? .swap : .wordCard] }

        return weightedPick(kinds) { kind in
            switch kind {
            case .wordCard: isKnown ? 1 : (isNew ? 5 : 2)
            case .swap: isNew ? 3 : 2
            case .quiz: isKnown ? 4 : (isNew ? 1 : 3)
            case .meeting: isKnown ? 3 : 2
            case .mistake: isNew ? 1 : 2
            case .review: focus.contains(word.word) ? 5 : 3
            case .dailyDone: 0
            }
        } ?? .wordCard
    }

    private mutating func makeContent(_ kind: FeedPost.Kind, for word: Word) -> FeedPost.Content? {
        switch kind {
        case .wordCard:
            return .wordCard(word)
        case .swap:
            return .swap(word)
        case .quiz:
            let wrong = QuizBuilder.distractors(for: word, from: allWords).prefix(2)
            guard wrong.count == 2 else { return nil }
            return .quiz(word, options: (Array(wrong) + [word]).shuffled(using: &rng))
        case .meeting:
            guard let dive = deepDive(for: word),
                  let example = meetingLines(for: word, in: dive).randomElement(using: &rng)
            else { return nil }
            return .meeting(word,
                            setting: example.setting,
                            strong: example.sentence,
                            weak: Self.weakLine(for: word, setting: example.setting),
                            strongFirst: Bool.random(using: &rng))
        case .mistake:
            guard let dive = deepDive(for: word), !dive.mistake.isEmpty else { return nil }
            return .mistake(word, mistake: dive.mistake, tip: dive.tip)
        case .review:
            return .review(word)
        case .dailyDone:
            return nil
        }
    }

    private mutating func record(_ content: FeedPost.Content, word: Word) -> FeedPost {
        let post = FeedPost(id: nextID, content: content)
        nextID += 1
        lastKind = post.kind
        recentWords.append(word.word)
        if recentWords.count > 8 { recentWords.removeFirst() }
        seenWords.insert(word.word)
        return post
    }

    private mutating func weightedPick<T>(_ items: [T], weight: (T) -> Double) -> T? {
        let weights = items.map { max(0, weight($0)) }
        let total = weights.reduce(0, +)
        guard total > 0 else { return items.randomElement(using: &rng) }
        var roll = Double.random(in: 0..<total, using: &rng)
        for (item, itemWeight) in zip(items, weights) {
            if roll < itemWeight { return item }
            roll -= itemWeight
        }
        return items.last
    }
}

/// Small seedable generator so feed generation is reproducible in tests.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
