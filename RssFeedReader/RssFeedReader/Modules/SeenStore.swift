import Foundation

struct SeenStore: Codable {
    /// feedURL -> stableIDの集合
    var seenIDsByFeedURL: [String: Set<String>] = [:]

    /// prune用（任意）
    var lastUpdatedAt: Date = .init()
}

final class SeenStoreRepository {
    private let key = "seen-store.v1"

    func load() -> SeenStore {
        guard let data = UserDefaults.standard.data(forKey: key) else { return SeenStore() }
        return (try? JSONDecoder().decode(SeenStore.self, from: data)) ?? SeenStore()
    }

    func save(_ store: SeenStore) {
        guard let data = try? JSONEncoder().encode(store) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
