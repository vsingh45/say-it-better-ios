import Foundation
import Observation
import SwiftData

/// How far the user got through each day's set, stored in SwiftData (`DailyFeedCount`).
struct DailyFeedProgress {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// "yyyy-MM-dd" in the user's calendar and time zone.
    static func dayKey(for date: Date = .now, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Posts viewed on `day`; 0 if nothing was recorded yet.
    func count(for day: String) -> Int {
        row(for: day)?.count ?? 0
    }

    func save(_ count: Int, for day: String) {
        if let row = row(for: day) {
            row.count = count
        } else {
            context.insert(DailyFeedCount(day: day, count: count))
        }
        try? context.save()
    }

    private func row(for day: String) -> DailyFeedCount? {
        var descriptor = FetchDescriptor<DailyFeedCount>(predicate: #Predicate { $0.day == day })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}

/// What the user has done on a post, kept outside the views so it survives lazy-stack recycling.
struct FeedResponse: Equatable {
    /// Swap / review: the hidden word has been revealed.
    var revealed = false
    /// Quiz: the option's word. Meeting: "strong" or "weak".
    var picked: String?
    /// Review: true for "Got it", false for "Still learning".
    var grade: Bool?
}

/// State for the Feed tab: the generated posts, the user's answers, and today's progress.
@Observable
final class FeedSession {
    private(set) var posts: [FeedPost] = []
    private(set) var responses: [Int: FeedResponse] = [:]
    private(set) var todayCount = 0

    @ObservationIgnored private var builder: FeedBuilder?
    @ObservationIgnored private var viewed: Set<Int> = []
    /// Words the user recently struggled with; they come back sooner.
    @ObservationIgnored private var focus: Set<String> = []
    @ObservationIgnored private var day = DailyFeedProgress.dayKey()
    @ObservationIgnored private var progress: DailyFeedProgress?

    private static let batchSize = 10

    /// Loads today's count from SwiftData. Call once the view has the model context.
    func start(context: ModelContext) {
        guard progress == nil else { return }
        let progress = DailyFeedProgress(context: context)
        self.progress = progress
        rollOverIfNewDay()
        todayCount = progress.count(for: day)
    }

    var goal: Int { FeedBuilder.dailyGoal }
    var isDailyGoalMet: Bool { todayCount >= goal }

    /// Starts a fresh feed, e.g. on first appearance or when the category filter changes.
    func rebuild(pool: [Word], allWords: [Word], deepDives: [String: DeepDive], known: Set<String>) {
        let firstID = (posts.map(\.id).max() ?? -1) + 1
        var builder = FeedBuilder(pool: pool, allWords: allWords, deepDives: deepDives, firstID: firstID)
        posts = builder.makeBatch(count: Self.batchSize, known: known, focus: focus)
        self.builder = builder
        responses = [:]
        viewed = []
    }

    func response(for post: FeedPost) -> FeedResponse {
        responses[post.id] ?? FeedResponse()
    }

    func update(_ post: FeedPost, _ change: (inout FeedResponse) -> Void) {
        var response = responses[post.id] ?? FeedResponse()
        change(&response)
        responses[post.id] = response
    }

    func noteStruggle(with word: Word) {
        focus.insert(word.word)
    }

    func noteLearned(_ word: Word) {
        focus.remove(word.word)
    }

    /// Call when `id` becomes the visible post: counts it toward today's set, inserts the
    /// "done for today" post right after the post that completes the set, and keeps a few
    /// posts generated ahead of the user.
    func didShow(postID id: Int, known: Set<String>) {
        guard let index = posts.firstIndex(where: { $0.id == id }) else { return }
        rollOverIfNewDay()

        if posts[index].kind != .dailyDone, viewed.insert(id).inserted {
            todayCount += 1
            progress?.save(todayCount, for: day)
            if todayCount == goal, var builder {
                posts.insert(builder.makeDailyDonePost(), at: index + 1)
                self.builder = builder
            }
        }

        if posts.count - index <= 4, var builder {
            posts += builder.makeBatch(count: Self.batchSize, known: known, focus: focus)
            self.builder = builder
        }
    }

    /// The id of the post after `id`, for the "Keep going" button.
    func postID(after id: Int) -> Int? {
        guard let index = posts.firstIndex(where: { $0.id == id }), posts.indices.contains(index + 1) else { return nil }
        return posts[index + 1].id
    }

    private func rollOverIfNewDay() {
        let today = DailyFeedProgress.dayKey()
        guard today != day else { return }
        day = today
        todayCount = progress?.count(for: today) ?? 0
    }
}
