import Foundation

/// Local JSON persistence in Application Support — fully offline.
final class PersistenceService {
    static let shared = PersistenceService()

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let queue = DispatchQueue(label: "com.shapesnap.persistence", qos: .utility)

    private init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("progress.json")
    }

    func load() -> ProgressSnapshot {
        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? decoder.decode(ProgressSnapshot.self, from: data) else {
            return ProgressSnapshot()
        }
        return snapshot
    }

    func save(_ snapshot: ProgressSnapshot) {
        queue.async { [fileURL, encoder] in
            guard let data = try? encoder.encode(snapshot) else { return }
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}

/// iCloud key-value store sync with last-writer-wins merge on meaningful progress.
final class CloudSyncService {
    static let shared = CloudSyncService()

    private let store = NSUbiquitousKeyValueStore.default
    private let key = "com.shapesnap.progress"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {}

    func start() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(storeChanged),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: store)
        store.synchronize()
        pullIfNewer()
    }

    func push(_ snapshot: ProgressSnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }
        store.set(data, forKey: key)
    }

    @objc private func storeChanged(_ note: Notification) {
        DispatchQueue.main.async { self.pullIfNewer() }
    }

    private func pullIfNewer() {
        guard let data = store.data(forKey: key),
              let remote = try? decoder.decode(ProgressSnapshot.self, from: data) else { return }
        let local = PlayerProgress.shared
        // Merge strategy: keep whichever save is further along; never lose coins/stars.
        if remote.highestUnlockedLevel > local.highestUnlockedLevel || remote.totalStars > local.totalStars {
            DispatchQueue.main.async { local.apply(remote) }
        }
    }
}
