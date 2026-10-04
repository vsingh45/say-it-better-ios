import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            FeedView()
                .tabItem { Label("Feed", systemImage: "play.square.stack") }
            LearnView()
                .tabItem { Label("Learn", systemImage: "rectangle.stack") }
            QuizView()
                .tabItem { Label("Quiz", systemImage: "checklist") }
            MyWordsView()
                .tabItem { Label("My words", systemImage: "checkmark.seal") }
            AllWordsView()
                .tabItem { Label("All words", systemImage: "text.book.closed") }
        }
    }
}

#Preview {
    RootView()
        .environment(WordStore())
        .environment(DeepDiveService())
        .modelContainer(for: [QuizResult.self, KnownWord.self, DailyFeedCount.self, HeardWord.self], inMemory: true)
}
