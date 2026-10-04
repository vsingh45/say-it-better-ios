import Foundation
import SwiftData

/// How many Feed posts the user viewed on one day. One row per "yyyy-MM-dd" day.
@Model
final class DailyFeedCount {
    @Attribute(.unique) var day: String
    var count: Int

    init(day: String, count: Int) {
        self.day = day
        self.count = count
    }
}
