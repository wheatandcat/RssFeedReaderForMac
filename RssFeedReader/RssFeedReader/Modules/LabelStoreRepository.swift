import Foundation

final class LabelStoreRepository {
    private let key = "article-labels.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> LabelStore {
        guard let data = defaults.data(forKey: key) else { return LabelStore() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(LabelStore.self, from: data)) ?? LabelStore()
    }

    func save(_ store: LabelStore) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(store) else {
            print("[LabelingPipeline] error: Failed to save label store")
            return
        }
        defaults.set(data, forKey: key)
    }
}
