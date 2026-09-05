import Foundation

/// JSON-file persistence. Writes go to local Documents (synchronous) and are
/// mirrored to the iCloud Documents container in the background. On first launch
/// after a reinstall, stores can restore from iCloud if the local file is absent.
enum LocalStore {

    // MARK: – Directories

    static var localDirectory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("KindredTable", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // Called once at app start on a background thread.
    private static func cloudDirectory() -> URL? {
        guard let container = FileManager.default.url(forUbiquityContainerIdentifier: nil) else { return nil }
        let dir = container.appendingPathComponent("Documents/KindredTable", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: – Synchronous local I/O (main-thread safe)

    static func load<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        let url = localDirectory.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static func save<T: Encodable>(_ value: T, to name: String) {
        let url = localDirectory.appendingPathComponent(name)
        do {
            let data = try JSONEncoder().encode(value)
            try data.write(to: url, options: .atomic)
        } catch {
            #if DEBUG
            print("LocalStore save failed for \(name): \(error)")
            #endif
        }
    }

    // MARK: – iCloud backup (fire-and-forget, background)

    /// Mirror a local file to iCloud after every save. Failures are silent —
    /// local data is always the authoritative copy.
    static func backupToCloud(_ name: String) {
        Task.detached(priority: .background) {
            guard let cloudDir = cloudDirectory() else { return }
            let localURL = localDirectory.appendingPathComponent(name)
            guard let data = try? Data(contentsOf: localURL) else { return }
            let cloudURL = cloudDir.appendingPathComponent(name)
            let coordinator = NSFileCoordinator()
            var err: NSError?
            coordinator.coordinate(writingItemAt: cloudURL, options: .forReplacing, error: &err) { dest in
                try? data.write(to: dest, options: .atomic)
            }
        }
    }

    // MARK: – iCloud restore (async, used on init when local is empty)

    /// Returns decoded data from iCloud if available, or nil. Safe to call from
    /// any thread; uses NSFileCoordinator for read safety.
    static func restoreFromCloud<T: Decodable>(_ type: T.Type, from name: String) async -> T? {
        return await Task.detached(priority: .background) {
            guard let cloudDir = cloudDirectory() else { return nil }
            let cloudURL = cloudDir.appendingPathComponent(name)
            var result: T? = nil
            let coordinator = NSFileCoordinator()
            var err: NSError?
            coordinator.coordinate(readingItemAt: cloudURL, options: .withoutChanges, error: &err) { src in
                guard let data = try? Data(contentsOf: src) else { return }
                result = try? JSONDecoder().decode(T.self, from: data)
            }
            return result
        }.value
    }

    // MARK: – One-time migration (local → iCloud)

    /// Copies any JSON files that exist locally but not yet in iCloud.
    /// Called once per install from the app entry point.
    static func migrateLocalToCloudIfNeeded() {
        Task.detached(priority: .background) {
            let key = "kt_icloud_migrated_v1"
            guard !UserDefaults.standard.bool(forKey: key) else { return }
            guard let cloudDir = cloudDirectory() else { return }
            let fm = FileManager.default
            guard let files = try? fm.contentsOfDirectory(at: localDirectory,
                                                          includingPropertiesForKeys: nil) else { return }
            for file in files where file.pathExtension == "json" {
                let dest = cloudDir.appendingPathComponent(file.lastPathComponent)
                guard !fm.fileExists(atPath: dest.path) else { continue }
                let coordinator = NSFileCoordinator()
                var err: NSError?
                coordinator.coordinate(writingItemAt: dest, options: .forReplacing, error: &err) { writeURL in
                    try? fm.copyItem(at: file, to: writeURL)
                }
            }
            UserDefaults.standard.set(true, forKey: key)
        }
    }
}
