import Foundation

final class HistoryStoreRepository {
    private let key = "history-store.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> HistoryStore {
        guard let data = defaults.data(forKey: key) else { return HistoryStore() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(HistoryStore.self, from: data)) ?? HistoryStore()
    }

    func save(_ store: HistoryStore) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(store) else {
            print("❌ Failed to save history store")
            return
        }
        defaults.set(data, forKey: key)
    }
}
