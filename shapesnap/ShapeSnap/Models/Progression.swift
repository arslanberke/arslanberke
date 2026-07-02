import Foundation
import SwiftUI
import Combine

/// All persistent player state. Persisted locally and mirrored to iCloud KVS.
final class PlayerProgress: ObservableObject {
    static let shared = PlayerProgress()

    @Published var coins: Int
    @Published var totalStars: Int
    @Published var perfectMedals: Int
    @Published var results: [Int: LevelResult]          // best result per story level
    @Published var highestUnlockedLevel: Int
    @Published var perfectStreak: Int
    @Published var bestPerfectStreak: Int
    @Published var branchChoices: [Int: BranchPath]     // world id -> chosen path
    @Published var unlockedThemes: Set<String>
    @Published var selectedTheme: String
    @Published var unlockedAchievements: Set<String>
    @Published var dailyCompletions: Set<String>        // "yyyy-MM-dd"
    @Published var endlessBest: Int
    @Published var timeAttackBest: Int
    @Published var lastLoginDate: Date?
    @Published var loginStreak: Int
    @Published var removeAdsPurchased: Bool

    private var cancellables = Set<AnyCancellable>()

    private init() {
        let saved = PersistenceService.shared.load()
        coins = saved.coins
        totalStars = saved.totalStars
        perfectMedals = saved.perfectMedals
        results = saved.results
        highestUnlockedLevel = saved.highestUnlockedLevel
        perfectStreak = saved.perfectStreak
        bestPerfectStreak = saved.bestPerfectStreak
        branchChoices = saved.branchChoices
        unlockedThemes = saved.unlockedThemes
        selectedTheme = saved.selectedTheme
        unlockedAchievements = saved.unlockedAchievements
        dailyCompletions = saved.dailyCompletions
        endlessBest = saved.endlessBest
        timeAttackBest = saved.timeAttackBest
        lastLoginDate = saved.lastLoginDate
        loginStreak = saved.loginStreak
        removeAdsPurchased = saved.removeAdsPurchased

        objectWillChange
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] in self?.save() }
            .store(in: &cancellables)
    }

    func save() {
        PersistenceService.shared.save(snapshot())
        CloudSyncService.shared.push(snapshot())
    }

    func snapshot() -> ProgressSnapshot {
        ProgressSnapshot(coins: coins, totalStars: totalStars, perfectMedals: perfectMedals,
                         results: results, highestUnlockedLevel: highestUnlockedLevel,
                         perfectStreak: perfectStreak, bestPerfectStreak: bestPerfectStreak,
                         branchChoices: branchChoices, unlockedThemes: unlockedThemes,
                         selectedTheme: selectedTheme, unlockedAchievements: unlockedAchievements,
                         dailyCompletions: dailyCompletions, endlessBest: endlessBest,
                         timeAttackBest: timeAttackBest, lastLoginDate: lastLoginDate,
                         loginStreak: loginStreak, removeAdsPurchased: removeAdsPurchased)
    }

    func apply(_ s: ProgressSnapshot) {
        coins = s.coins; totalStars = s.totalStars; perfectMedals = s.perfectMedals
        results = s.results; highestUnlockedLevel = s.highestUnlockedLevel
        perfectStreak = s.perfectStreak; bestPerfectStreak = s.bestPerfectStreak
        branchChoices = s.branchChoices; unlockedThemes = s.unlockedThemes
        selectedTheme = s.selectedTheme; unlockedAchievements = s.unlockedAchievements
        dailyCompletions = s.dailyCompletions; endlessBest = s.endlessBest
        timeAttackBest = s.timeAttackBest; lastLoginDate = s.lastLoginDate
        loginStreak = s.loginStreak; removeAdsPurchased = s.removeAdsPurchased
    }

    /// Records a story-mode result and returns newly unlocked achievements.
    @discardableResult
    func record(result: LevelResult) -> [Achievement] {
        if result.rating == .perfect {
            perfectStreak += 1
            bestPerfectStreak = max(bestPerfectStreak, perfectStreak)
            if results[result.levelID]?.rating != .perfect { perfectMedals += 1 }
        } else if result.rating == .failed {
            perfectStreak = 0
        } else {
            perfectStreak = 0
        }

        let previousStars = results[result.levelID]?.stars ?? 0
        if result.score > (results[result.levelID]?.score ?? -1) {
            results[result.levelID] = result
        }
        totalStars += max(0, result.stars - previousStars)
        coins += result.coinsEarned

        if result.rating != .failed {
            highestUnlockedLevel = max(highestUnlockedLevel, result.levelID + 1)
        }

        GameCenterService.shared.reportStoryProgress(stars: totalStars, level: highestUnlockedLevel)
        return AchievementEngine.evaluate(progress: self, latest: result)
    }

    func stars(for levelID: Int) -> Int { results[levelID]?.stars ?? 0 }
    func isUnlocked(_ levelID: Int) -> Bool { levelID <= highestUnlockedLevel }
}

struct ProgressSnapshot: Codable {
    var coins = 0
    var totalStars = 0
    var perfectMedals = 0
    var results: [Int: LevelResult] = [:]
    var highestUnlockedLevel = 1
    var perfectStreak = 0
    var bestPerfectStreak = 0
    var branchChoices: [Int: BranchPath] = [:]
    var unlockedThemes: Set<String> = ["aurora"]
    var selectedTheme = "aurora"
    var unlockedAchievements: Set<String> = []
    var dailyCompletions: Set<String> = []
    var endlessBest = 0
    var timeAttackBest = 0
    var lastLoginDate: Date?
    var loginStreak = 0
    var removeAdsPurchased = false
}
