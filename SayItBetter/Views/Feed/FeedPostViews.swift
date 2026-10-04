import SwiftUI

/// Picks the view for a post.
struct FeedPostView: View {
    let post: FeedPost
    let session: FeedSession
    var showsSwipeHint = false
    /// Height of the tab bar the page runs underneath.
    var bottomInset: CGFloat = 0
    let onKeepGoing: () -> Void

    var body: some View {
        page
            .environment(\.feedBottomInset, bottomInset)
    }

    @ViewBuilder
    private var page: some View {
        switch post.content {
        case .wordCard(let word):
            FeedPage(kind: .wordCard, showsSwipeHint: showsSwipeHint) {
                WordCardPost(word: word, session: session)
            }
        case .swap(let word):
            FeedPage(kind: .swap, showsSwipeHint: showsSwipeHint) {
                SwapPost(word: word, post: post, session: session)
            }
        case .quiz(let word, let options):
            FeedPage(kind: .quiz, showsSwipeHint: showsSwipeHint) {
                QuizPost(word: word, options: options, post: post, session: session)
            }
        case .meeting(let word, let setting, let strong, let weak, let strongFirst):
            FeedPage(kind: .meeting, label: "Meeting moment · \(setting)", showsSwipeHint: showsSwipeHint) {
                MeetingPost(word: word, setting: setting, strong: strong, weak: weak,
                            strongFirst: strongFirst, post: post, session: session)
            }
        case .mistake(let word, let mistake, let tip):
            FeedPage(kind: .mistake, showsSwipeHint: showsSwipeHint) {
                MistakePost(word: word, mistake: mistake, tip: tip)
            }
        case .review(let word):
            FeedPage(kind: .review, showsSwipeHint: showsSwipeHint) {
                ReviewPost(word: word, post: post, session: session)
            }
        case .dailyDone:
            FeedPage(kind: .dailyDone) {
                DailyDonePost(goal: session.goal, onKeepGoing: onKeepGoing)
            }
        }
    }
}

// MARK: - Word card

struct WordCardPost: View {
    let word: Word
    let session: FeedSession

    @Environment(WordStore.self) private var store
    @State private var showsDeepDive = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // The word, meaning and example scroll if they are long; the actions below stay pinned.
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        WordMeta(word: word)
                        HStack(alignment: .center) {
                            FeedHeadword(text: word.word, baseSize: 36)
                            Spacer(minLength: 8)
                            HearItButton(text: word.word)
                        }
                    }

                    Text(word.definition)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel("In a sentence")
                        HighlightedExample(word: word, font: Theme.serif(.body, weight: .regular))
                    }
                }
            }
            .scrollIndicators(.hidden)
            .frame(minHeight: 120, maxHeight: .infinity, alignment: .top)

            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    Button {
                        session.noteStruggle(with: word)
                    } label: {
                        Text("Still learning").lineLimit(1).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    if !store.isKnown(word) {
                        Button {
                            store.setKnown(true, for: word)
                            session.noteLearned(word)
                        } label: {
                            Text("I know this").lineLimit(1).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                Button {
                    showsDeepDive = true
                } label: {
                    Label("Go deeper", systemImage: "text.magnifyingglass").lineLimit(1).frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.regular)

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel("How to use")
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(Array(word.goesWith.prefix(3)), id: \.self) { phrase in
                            Text(phrase)
                                .font(.subheadline)
                                .lineLimit(1)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.accentColor.opacity(0.1), in: Capsule())
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .sheet(isPresented: $showsDeepDive) { DeepDiveSheet(word: word) }
    }
}

// MARK: - Swap

private struct SwapPost: View {
    let word: Word
    let post: FeedPost
    let session: FeedSession

    private var revealed: Bool { session.response(for: post).revealed }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Instead of saying")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("“\(word.insteadOf)”…")
                    .font(Theme.serif(.largeTitle, weight: .regular))
                    .italic()
                    .fixedSize(horizontal: false, vertical: true)
                Text("a lead would say")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            if revealed {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center) {
                        FeedHeadword(text: word.word, color: FeedPost.Kind.swap.tint)
                        Spacer(minLength: 8)
                        HearItButton(text: word.word)
                    }
                    Text(word.definition)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .transition(.flip)
            } else {
                Button {
                    withAnimation(.spring(duration: 0.5, bounce: 0.25)) {
                        session.update(post) { $0.revealed = true }
                    }
                } label: {
                    Label("Tap to reveal", systemImage: "eye")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(FeedPost.Kind.swap.tint)
                .controlSize(.large)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: revealed)
    }
}

// MARK: - Quick quiz

private struct QuizPost: View {
    let word: Word
    let options: [Word]
    let post: FeedPost
    let session: FeedSession

    private var picked: String? { session.response(for: post).picked }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel("Fill the blank")
                Text(word.blankedExample)
                    .font(Theme.serif(.title2, weight: .regular))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                ForEach(options) { option in
                    ChoiceButton(
                        title: option.word,
                        font: Theme.serif(.title3, weight: .medium),
                        status: .init(isAnswer: option.word == word.word,
                                      isPicked: option.word == picked,
                                      answered: picked != nil)
                    ) {
                        choose(option)
                    }
                }
            }

            if let picked {
                FeedbackLine(correct: picked == word.word,
                             right: "That's it.",
                             wrong: "It's \(word.word).",
                             detail: word.definition)
            }
        }
        .sensoryFeedback(trigger: picked) { _, new in
            guard let new else { return nil }
            return new == word.word ? .success : .error
        }
    }

    private func choose(_ option: Word) {
        guard picked == nil else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            session.update(post) { $0.picked = option.word }
        }
        if option.word != word.word { session.noteStruggle(with: word) }
    }
}

// MARK: - Meeting moment

private struct MeetingPost: View {
    let word: Word
    let setting: String
    let strong: String
    let weak: String
    let strongFirst: Bool
    let post: FeedPost
    let session: FeedSession

    private static let strongKey = "strong"
    private static let weakKey = "weak"

    private var picked: String? { session.response(for: post).picked }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Which line sounds stronger?")
                .font(Theme.serif(.title2))
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                ForEach(strongFirst ? [Self.strongKey, Self.weakKey] : [Self.weakKey, Self.strongKey], id: \.self) { key in
                    ChoiceButton(
                        title: key == Self.strongKey ? strong : weak,
                        font: Theme.serif(.body, weight: .regular),
                        status: .init(isAnswer: key == Self.strongKey,
                                      isPicked: key == picked,
                                      answered: picked != nil)
                    ) {
                        choose(key)
                    }
                }
            }

            if let picked {
                FeedbackLine(correct: picked == Self.strongKey,
                             right: "Yes. \(word.word.capitalized) does the work.",
                             wrong: "The other one: \(word.word) says it precisely.",
                             detail: word.definition)
            }
        }
        .sensoryFeedback(trigger: picked) { _, new in
            guard let new else { return nil }
            return new == Self.strongKey ? .success : .error
        }
    }

    private func choose(_ key: String) {
        guard picked == nil else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            session.update(post) { $0.picked = key }
        }
        if key != Self.strongKey { session.noteStruggle(with: word) }
    }
}

// MARK: - Common mistake

private struct MistakePost: View {
    let word: Word
    let mistake: String
    let tip: String

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Common mistake with")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                HStack(alignment: .center) {
                    FeedHeadword(text: word.word)
                    Spacer(minLength: 8)
                    HearItButton(text: word.word)
                }
            }

            Text(mistake)
                .font(Theme.serif(.title3, weight: .regular))
                .fixedSize(horizontal: false, vertical: true)

            if !tip.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Memory tip", systemImage: "lightbulb")
                        .font(Theme.monoSmall)
                        .textCase(.uppercase)
                        .tracking(0.8)
                        .foregroundStyle(.secondary)
                    Text(tip)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(FeedPost.Kind.mistake.tint.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }
}

// MARK: - Review

private struct ReviewPost: View {
    @Environment(WordStore.self) private var store

    let word: Word
    let post: FeedPost
    let session: FeedSession

    private var response: FeedResponse { session.response(for: post) }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel("Which word means…")
                Text(word.definition)
                    .font(Theme.serif(.title2, weight: .regular))
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(word.partOfSpeech) · starts with “\(word.word.prefix(1))”")
                    .font(Theme.mono)
                    .foregroundStyle(.secondary)
            }

            if response.revealed {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center) {
                        FeedHeadword(text: word.word, color: FeedPost.Kind.review.tint)
                        Spacer(minLength: 8)
                        HearItButton(text: word.word)
                    }
                    HighlightedExample(word: word, font: .subheadline)
                        .foregroundStyle(.secondary)
                }
                .transition(.flip)

                if let grade = response.grade {
                    Label(grade ? "Marked as known" : "It'll come back soon",
                          systemImage: grade ? "checkmark.seal.fill" : "arrow.counterclockwise")
                        .font(.headline)
                        .foregroundStyle(grade ? Color.green : FeedPost.Kind.review.tint)
                        .transition(.opacity)
                } else {
                    HStack(spacing: 12) {
                        Button {
                            grade(false)
                        } label: {
                            Text("Still learning").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            grade(true)
                        } label: {
                            Text("Got it").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .controlSize(.large)
                }
            } else {
                Button {
                    withAnimation(.spring(duration: 0.35)) {
                        session.update(post) { $0.revealed = true }
                    }
                } label: {
                    Label("Show the word", systemImage: "eye")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(FeedPost.Kind.review.tint)
                .controlSize(.large)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: response.revealed)
        .sensoryFeedback(trigger: response.grade) { _, new in
            new == true ? .success : nil
        }
    }

    private func grade(_ gotIt: Bool) {
        withAnimation(.easeInOut(duration: 0.2)) {
            session.update(post) { $0.grade = gotIt }
        }
        if gotIt {
            store.setKnown(true, for: word)
            session.noteLearned(word)
        } else {
            store.setKnown(false, for: word)
            session.noteStruggle(with: word)
        }
    }
}

// MARK: - Done for today

private struct DailyDonePost: View {
    let goal: Int
    let onKeepGoing: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundStyle(FeedPost.Kind.dailyDone.tint)
                .symbolRenderingMode(.hierarchical)
                .symbolEffect(.bounce, options: .repeat(2))
                .background { ConfettiBurst() }
                .accessibilityHidden(true)
            Text("You're done for today ✓")
                .font(Theme.serif(.largeTitle))
                .multilineTextAlignment(.center)
            Text("\(goal) swipes, and every one taught you something. Come back tomorrow for a fresh set.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onKeepGoing) {
                Label("Keep going", systemImage: "arrow.down")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(FeedPost.Kind.dailyDone.tint)
            .controlSize(.large)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Shared

/// "That's it." / "It's X." plus the meaning, after answering a quiz or meeting post.
private struct FeedbackLine: View {
    let correct: Bool
    let right: String
    let wrong: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(correct ? right : wrong,
                  systemImage: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.headline)
                .foregroundStyle(correct ? Color.green : Color.red)
                .symbolEffect(.bounce, value: correct)
                .contentTransition(.symbolEffect(.replace))
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}
