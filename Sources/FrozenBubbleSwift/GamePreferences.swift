import Foundation

final class GamePreferences {
    static let shared = GamePreferences()

    private struct StoredPreferences: Codable {
        var lastReachedLevel = 0
        var highestUnlockedLevel = 0
        var bestScoresByLevel: [String: Int] = [:]
        var bestRunScore = 0
        var soundEnabled = true
        var musicEnabled = true
        var colorBlindEnabled = false
        var rushMeEnabled = false
    }

    private let fileURL: URL
    private var stored: StoredPreferences

    private init() {
        fileURL = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/de.twocent.frozenbubble.plist")
        stored = Self.load(from: fileURL)
    }

    var lastReachedLevel: Int {
        get { max(0, stored.lastReachedLevel) }
        set {
            stored.lastReachedLevel = max(0, newValue)
            save()
        }
    }

    var highestUnlockedLevel: Int {
        get { max(0, stored.highestUnlockedLevel) }
        set {
            stored.highestUnlockedLevel = max(0, newValue)
            save()
        }
    }

    func bestScore(for level: Int) -> Int {
        stored.bestScoresByLevel[levelKey(level)] ?? 0
    }

    var bestRunScore: Int {
        max(0, stored.bestRunScore)
    }

    var soundEnabled: Bool {
        get { stored.soundEnabled }
        set {
            stored.soundEnabled = newValue
            save()
        }
    }

    var musicEnabled: Bool {
        get { stored.musicEnabled }
        set {
            stored.musicEnabled = newValue
            save()
        }
    }

    var colorBlindEnabled: Bool {
        get { stored.colorBlindEnabled }
        set {
            stored.colorBlindEnabled = newValue
            save()
        }
    }

    var rushMeEnabled: Bool {
        get { stored.rushMeEnabled }
        set {
            stored.rushMeEnabled = newValue
            save()
        }
    }

    func recordCompletion(level: Int, levelScore: Int, runScore: Int, nextLevel: Int) {
        let key = levelKey(level)
        stored.bestScoresByLevel[key] = max(stored.bestScoresByLevel[key] ?? 0, levelScore)
        stored.bestRunScore = max(stored.bestRunScore, runScore)
        stored.highestUnlockedLevel = max(highestUnlockedLevel, nextLevel)
        stored.lastReachedLevel = nextLevel
        save()
    }

    func recordRunScore(_ runScore: Int) {
        stored.bestRunScore = max(stored.bestRunScore, runScore)
        save()
    }

    func resetRun() {
        stored.lastReachedLevel = 0
        save()
    }

    private func levelKey(_ level: Int) -> String {
        String(max(0, level))
    }

    private static func load(from url: URL) -> StoredPreferences {
        guard let data = try? Data(contentsOf: url) else {
            return StoredPreferences()
        }

        if let preferences = try? PropertyListDecoder().decode(StoredPreferences.self, from: data) {
            return preferences
        }

        if let object = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
           let dictionary = object as? [String: Any] {
            return StoredPreferences(
                lastReachedLevel: dictionary["lastReachedLevel"] as? Int ?? 0,
                highestUnlockedLevel: dictionary["highestUnlockedLevel"] as? Int ?? 0,
                bestScoresByLevel: dictionary["bestScoresByLevel"] as? [String: Int] ?? [:],
                bestRunScore: dictionary["bestRunScore"] as? Int ?? 0,
                soundEnabled: dictionary["soundEnabled"] as? Bool ?? true,
                musicEnabled: dictionary["musicEnabled"] as? Bool ?? true,
                colorBlindEnabled: dictionary["colorBlindEnabled"] as? Bool ?? false,
                rushMeEnabled: dictionary["rushMeEnabled"] as? Bool ?? false
            )
        }

        return StoredPreferences()
    }

    private func save() {
        do {
            let data = try PropertyListEncoder().encode(stored)
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("Could not save Frozen Bubble preferences: \(error)")
        }
    }
}
