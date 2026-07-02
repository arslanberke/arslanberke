import Foundation

struct Achievement: Identifiable, Hashable {
    let id: String
    let name: String
    let detail: String
    let symbolName: String
    let gameCenterID: String
    let condition: (PlayerProgress, LevelResult?) -> Bool

    static func == (lhs: Achievement, rhs: Achievement) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    static let all: [Achievement] = [
        Achievement(id: "first_snap", name: "First Snap", detail: "Complete your first level",
                    symbolName: "puzzlepiece.fill", gameCenterID: "com.shapesnap.ach.first",
                    condition: { p, _ in !p.results.isEmpty }),
        Achievement(id: "perfect_10", name: "Flawless Ten", detail: "10 perfect levels in a row",
                    symbolName: "star.circle.fill", gameCenterID: "com.shapesnap.ach.streak10",
                    condition: { p, _ in p.bestPerfectStreak >= 10 }),
        Achievement(id: "world_1", name: "Graduate", detail: "Finish World 1",
                    symbolName: "graduationcap.fill", gameCenterID: "com.shapesnap.ach.world1",
                    condition: { p, _ in p.highestUnlockedLevel > 50 }),
        Achievement(id: "world_5", name: "Halfway There", detail: "Finish World 5",
                    symbolName: "flag.fill", gameCenterID: "com.shapesnap.ach.world5",
                    condition: { p, _ in p.highestUnlockedLevel > 250 }),
        Achievement(id: "world_10", name: "Gauntlet Slayer", detail: "Finish all 600 levels",
                    symbolName: "crown.fill", gameCenterID: "com.shapesnap.ach.world10",
                    condition: { p, _ in p.highestUnlockedLevel > 600 }),
        Achievement(id: "stars_100", name: "Constellation", detail: "Collect 100 stars",
                    symbolName: "sparkles", gameCenterID: "com.shapesnap.ach.stars100",
                    condition: { p, _ in p.totalStars >= 100 }),
        Achievement(id: "stars_1000", name: "Galaxy", detail: "Collect 1000 stars",
                    symbolName: "moon.stars.fill", gameCenterID: "com.shapesnap.ach.stars1000",
                    condition: { p, _ in p.totalStars >= 1000 }),
        Achievement(id: "coins_1000", name: "Piggy Bank", detail: "Hold 1000 coins",
                    symbolName: "dollarsign.circle.fill", gameCenterID: "com.shapesnap.ach.coins",
                    condition: { p, _ in p.coins >= 1000 }),
        Achievement(id: "boss_first", name: "Boss Down", detail: "Beat a boss level",
                    symbolName: "bolt.shield.fill", gameCenterID: "com.shapesnap.ach.boss",
                    condition: { p, r in
                        guard let r else { return false }
                        return LevelCatalog.shared.level(id: r.levelID)?.isBoss == true && r.rating != .failed
                    }),
        Achievement(id: "speedster", name: "Speedster", detail: "Finish any level under 5 seconds",
                    symbolName: "hare.fill", gameCenterID: "com.shapesnap.ach.speed",
                    condition: { _, r in (r?.time ?? .infinity) < 5 && r?.rating != .failed }),
        Achievement(id: "daily_7", name: "Regular", detail: "Complete 7 daily challenges",
                    symbolName: "calendar.badge.checkmark", gameCenterID: "com.shapesnap.ach.daily7",
                    condition: { p, _ in p.dailyCompletions.count >= 7 }),
        Achievement(id: "endless_25", name: "Marathon", detail: "Reach round 25 in Endless",
                    symbolName: "infinity.circle.fill", gameCenterID: "com.shapesnap.ach.endless",
                    condition: { p, _ in p.endlessBest >= 25 }),
    ]
}

enum AchievementEngine {
    /// Returns achievements newly unlocked by the latest result.
    static func evaluate(progress: PlayerProgress, latest: LevelResult?) -> [Achievement] {
        var unlocked: [Achievement] = []
        for achievement in Achievement.all where !progress.unlockedAchievements.contains(achievement.id) {
            if achievement.condition(progress, latest) {
                progress.unlockedAchievements.insert(achievement.id)
                GameCenterService.shared.reportAchievement(achievement.gameCenterID)
                unlocked.append(achievement)
            }
        }
        return unlocked
    }
}
