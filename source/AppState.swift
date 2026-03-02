import AppKit
import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var isActive = true
    @Published private(set) var isRefetchingRules = false
    @Published private(set) var rulesStatusMessage: String?
    @Published private(set) var totalParamsRemoved: Int

    private let cleaner: URLCleaner
    private let watcher: ClipboardWatcher
    private let persistence: PersistentStateStore
    private var terminationObserver: NSObjectProtocol?

    init() {
        cleaner = URLCleaner()
        watcher = ClipboardWatcher(cleaner: cleaner)
        persistence = PersistentStateStore()

        let persisted = persistence.load()
        totalParamsRemoved = persisted.totalParamsRemoved

        watcher.onURLProcessed = { [weak self] cleanedURL, removedCount in
            guard let self else { return }
            if removedCount > 0 {
                self.totalParamsRemoved += removedCount
            }
            self.persistence.save(
                lastCleanedURL: cleanedURL,
                totalParamsRemoved: self.totalParamsRemoved
            )
        }

        watcher.start()
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.watcher.stop()
            }
        }
    }

    deinit {
        if let terminationObserver {
            NotificationCenter.default.removeObserver(terminationObserver)
        }
    }

    func toggleActive() {
        isActive ? pause() : activate()
    }

    func refetchRules() {
        guard !isRefetchingRules else { return }
        isRefetchingRules = true
        rulesStatusMessage = "Refetching rules..."

        Task { [weak self] in
            guard let self else { return }
            let status = await cleaner.refetchRulesManually()
            self.rulesStatusMessage = status.message
            self.isRefetchingRules = false
        }
    }

    func resetCounter() {
        totalParamsRemoved = 0
        let previousURL = persistence.load().lastCleanedURL
        persistence.save(lastCleanedURL: previousURL, totalParamsRemoved: 0)
    }

    func pause() {
        guard isActive else { return }
        isActive = false
        watcher.stop()
    }

    func activate() {
        guard !isActive else { return }
        isActive = true
        watcher.start()
    }
}

private struct PersistedState: Codable {
    var lastCleanedURL: String?
    var totalParamsRemoved: Int

    static let empty = PersistedState(lastCleanedURL: nil, totalParamsRemoved: 0)
}

private final class PersistentStateStore {
    private let fileManager = FileManager.default

    func load() -> PersistedState {
        let fileURL = stateFileURL()
        guard let data = try? Data(contentsOf: fileURL),
              let state = try? JSONDecoder().decode(PersistedState.self, from: data) else {
            return .empty
        }
        return state
    }

    func save(lastCleanedURL: String?, totalParamsRemoved: Int) {
        let state = PersistedState(lastCleanedURL: lastCleanedURL, totalParamsRemoved: totalParamsRemoved)
        let fileURL = stateFileURL()
        let directory = fileURL.deletingLastPathComponent()

        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(state)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            // Persistence is best-effort.
        }
    }

    private func stateFileURL() -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return base
            .appendingPathComponent("PurePaste", isDirectory: true)
            .appendingPathComponent("state.json")
    }
}
