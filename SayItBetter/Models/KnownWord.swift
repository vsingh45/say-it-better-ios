import Foundation
import SwiftData

/// A word the user has marked "I know this". Presence in the table means known; "Relearn" deletes the row.
@Model
final class KnownWord {
    @Attribute(.unique) var word: String
    var date: Date

    init(word: String, date: Date = .now) {
        self.word = word
        self.date = date
    }
}
