import SwiftUI

/// A vertical, full-screen swipe feed: same thumb motion as a short-video app, but every swipe
/// is a word card, a swap, a quick quiz, a meeting moment, a common mistake or a review.
struct FeedView: View {
    @Environment(WordStore.self) private var store
    @Environment(DeepDiveService.self) private var deepDives
    @Environment(\.modelContext) private var modelContext

    @State private var session = FeedSession()
    @State private var currentID: Int?
    @State private var hasSwiped = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                CategoryChips()
                HStack(spacing: 10) {
                    DailyProgressBar(count: session.todayCount, goal: session.goal)
                    Text(session.isDailyGoalMet ? "Daily set ✓" : "\(session.todayCount)/\(session.goal) today")
                        .font(Theme.monoSmall)
                        .foregroundStyle(session.isDailyGoalMet ? Color.green : .secondary)
                        .monospacedDigit()
                        .fixedSize()
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                }
                .padding(.horizontal)
                    .padding(.bottom, 6)
                feed
            }
            .background(Theme.background)
            .navigationTitle("Feed")
            .navigationBarTitleDisplayMode(.inline)
            .settingsToolbar()
            .heardSearch()
            .onAppear {
                session.start(context: modelContext)
                if session.posts.isEmpty { rebuild() }
            }
            .onChange(of: store.categoryFilter) { rebuild() }
            .onChange(of: currentID) { _, newID in
                guard let newID else { return }
                if newID != session.posts.first?.id { hasSwiped = true }
                session.didShow(postID: newID, known: store.known)
            }
        }
    }

    /// Pages run edge to edge under the floating tab bar (each page pads its own content above
    /// it), so the scroll view has no bottom inset and paging, programmatic scrolls included,
    /// lands exactly on page boundaries.
    private var feed: some View {
        GeometryReader { proxy in
            let bottomInset = proxy.safeAreaInsets.bottom
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(session.posts) { post in
                        FeedPostView(
                            post: post,
                            session: session,
                            showsSwipeHint: !hasSwiped && post.id == session.posts.first?.id,
                            bottomInset: bottomInset
                        ) {
                            keepGoing(after: post.id)
                        }
                        .containerRelativeFrame([.horizontal, .vertical])
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $currentID, anchor: .top)
            .ignoresSafeArea(.container, edges: .bottom)
        }
        .overlay {
            if session.posts.isEmpty {
                ContentUnavailableView("No words here", systemImage: "rectangle.stack",
                                       description: Text("Pick another category to fill your feed."))
            }
        }
    }

    private func rebuild() {
        let bundled = Dictionary(
            store.words.compactMap { word in
                deepDives.bundledDeepDive(for: word.word).map { (word.word.lowercased(), $0) }
            },
            uniquingKeysWith: { first, _ in first }
        )
        session.rebuild(pool: store.filteredWords, allWords: store.words, deepDives: bundled, known: store.known)
        hasSwiped = false
        // Counted toward today's set by the onChange(of: currentID) handler.
        currentID = session.posts.first?.id
    }

    private func keepGoing(after id: Int) {
        guard let next = session.postID(after: id) else { return }
        withAnimation(.easeInOut(duration: 0.35)) {
            currentID = next
        }
    }
}

/// Slim segmented progress for the daily set of posts.
private struct DailyProgressBar: View {
    let count: Int
    let goal: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<goal, id: \.self) { index in
                Capsule()
                    .fill(index < count ? Color.accentColor : Theme.hairline.opacity(0.6))
                    .frame(height: 4)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: count)
        .accessibilityElement()
        .accessibilityLabel("Daily set")
        .accessibilityValue("\(min(count, goal)) of \(goal)")
    }
}

#Preview {
    FeedView()
        .environment(WordStore())
        .environment(DeepDiveService())
}
