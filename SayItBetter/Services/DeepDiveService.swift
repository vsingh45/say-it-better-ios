import Foundation
import Observation

/// Supplies the bundled Deep dive content. Live explanations and sentence feedback are written
/// on the iPhone by the on-device model (see `OnDeviceLookup`).
@MainActor
@Observable
final class DeepDiveService {
    enum Source: Equatable {
        case live
        case bundled
    }

    private let bundled: [String: DeepDive]

    init(bundle: Bundle = .main) {
        bundled = Self.loadBundled(bundle: bundle)
    }

    func bundledDeepDive(for word: String) -> DeepDive? {
        bundled[word.lowercased()]
    }

    private static func loadBundled(bundle: Bundle) -> [String: DeepDive] {
        guard
            let url = bundle.url(forResource: "deepdive", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let entries = try? JSONDecoder().decode([DeepDive].self, from: data)
        else {
            assertionFailure("deepdive.json is missing or malformed")
            return [:]
        }
        return Dictionary(entries.map { ($0.word.lowercased(), $0) }, uniquingKeysWith: { first, _ in first })
    }
}
