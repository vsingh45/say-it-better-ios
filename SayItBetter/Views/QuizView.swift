import SwiftUI
import SwiftData

struct QuizView: View {
    @Environment(WordStore.self) private var store
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \QuizResult.date, order: .reverse) private var history: [QuizResult]

    @State private var questions: [QuizQuestion] = []
    @State private var index = 0
    @State private var selected: Word?
    @State private var score = 0
    @State private var finished = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                CategoryChips()
                ScrollView {
                    Group {
                        if finished {
                            results
                        } else if questions.indices.contains(index) {
                            questionView(questions[index])
                        } else {
                            ContentUnavailableView("No known words yet", systemImage: "questionmark.circle",
                                                   description: Text("Mark words as “I know this” in Learn or the Feed, then come back to quiz yourself on them."))
                        }
                    }
                    .padding()
                }
            }
            .background(Theme.background)
            .navigationTitle("Quiz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !finished, !questions.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Text("\(index + 1)/\(questions.count) · \(score) right")
                            .font(Theme.monoSmall)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .settingsToolbar()
            .heardSearch()
            .onAppear {
                if questions.isEmpty { newRound() }
            }
            .onChange(of: store.categoryFilter) { newRound() }
        }
    }

    // MARK: - Question

    private func questionView(_ question: QuizQuestion) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(question.kind == .fillBlank ? "Fill the blank" : "Say it better")
                switch question.kind {
                case .fillBlank:
                    Text(question.answer.blankedExample)
                        .font(Theme.serif(.title3, weight: .regular))
                case .sayItBetter:
                    (Text("Instead of saying ")
                        + Text("“\(question.answer.insteadOf)”").italic()
                        + Text(", a lead would say…"))
                        .font(Theme.serif(.title3, weight: .regular))
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .card()

            VStack(spacing: 10) {
                ForEach(question.options) { option in
                    optionButton(option, answer: question.answer)
                }
            }

            if selected != nil {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(question.answer.word)
                            .font(Theme.serif(.title2))
                        Text(question.answer.partOfSpeech)
                            .font(Theme.monoSmall)
                            .foregroundStyle(.secondary)
                        Spacer()
                        HearItButton(text: question.answer.word)
                    }
                    Text(question.answer.definition)
                    HighlightedExample(word: question.answer, font: .subheadline)
                        .foregroundStyle(.secondary)
                }
                .card()

                Button {
                    next()
                } label: {
                    Text(index + 1 < questions.count ? "Next question" : "See results")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selected)
    }

    private func optionButton(_ option: Word, answer: Word) -> some View {
        ChoiceButton(
            title: option.word,
            status: .init(isAnswer: option.word == answer.word,
                          isPicked: option.word == selected?.word,
                          answered: selected != nil)
        ) {
            guard selected == nil else { return }
            selected = option
            if option.word == answer.word { score += 1 }
        }
    }

    // MARK: - Results

    private var results: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("\(score) / \(questions.count)")
                    .font(Theme.serif(.largeTitle))
                Text(QuizBuilder.message(score: score, total: questions.count))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
            .card()

            Button {
                newRound()
            } label: {
                Text("New round").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if !history.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel("Recent rounds")
                    ForEach(history.prefix(5)) { result in
                        HStack {
                            Text(result.date, format: .dateTime.month().day().hour().minute())
                            Text(result.category ?? "All")
                                .font(Theme.monoSmall)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(result.score)/\(result.total)")
                                .font(Theme.mono)
                        }
                        .font(.subheadline)
                    }
                }
                .card()
            }
        }
    }

    // MARK: - Flow

    private func newRound() {
        // Quiz only the words the user has marked as known, within the chosen category.
        let pool = store.knownWords.filter { store.categoryFilter == nil || $0.category == store.categoryFilter }
        questions = QuizBuilder.makeRound(pool: pool, allWords: store.words)
        index = 0
        selected = nil
        score = 0
        finished = false
    }

    private func next() {
        selected = nil
        if index + 1 < questions.count {
            index += 1
        } else {
            finished = true
            modelContext.insert(QuizResult(score: score, total: questions.count, category: store.categoryFilter))
        }
    }
}

#Preview {
    QuizView()
        .environment(WordStore())
        .environment(DeepDiveService())
        .modelContainer(for: QuizResult.self, inMemory: true)
}
