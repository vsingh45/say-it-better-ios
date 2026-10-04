import SwiftUI
import SwiftData

@main
struct SayItBetterApp: App {
    private let container: ModelContainer
    @State private var store: WordStore
    @State private var deepDives = DeepDiveService()

    init() {
        do {
            container = try ModelContainer(for: QuizResult.self, KnownWord.self, DailyFeedCount.self, HeardWord.self)
        } catch {
            fatalError("Could not create the SwiftData store: \(error)")
        }
        _store = State(initialValue: WordStore(context: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(deepDives)
        }
        .modelContainer(container)
    }
}
