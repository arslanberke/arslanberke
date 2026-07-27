import Foundation

/// Daily challenge availability and identity.
enum DailyChallengeService {
    static func todayKey(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }

    static var completedToday: Bool {
        PlayerProgress.shared.dailyCompletions.contains(todayKey())
    }
}

/// Daily login rewards with an escalating 7-day cycle.
final class DailyRewardService {
    static let shared = DailyRewardService()

    /// Coins for each consecutive login day (cycles weekly).
    static let rewardCycle = [20, 30, 40, 50, 70, 90, 150]

    private(set) var pendingReward: Int?

    private init() {}

    /// Called on app launch. Grants the reward once per calendar day.
    func checkIn() {
        let progress = PlayerProgress.shared
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let last = progress.lastLoginDate {
            let lastDay = calendar.startOfDay(for: last)
            guard today > lastDay else { return }   // already checked in today
            let gap = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
            progress.loginStreak = gap == 1 ? progress.loginStreak + 1 : 1
        } else {
            progress.loginStreak = 1
        }

        progress.lastLoginDate = Date()
        let reward = Self.rewardCycle[(progress.loginStreak - 1) % Self.rewardCycle.count]
        progress.coins += reward
        pendingReward = reward
        AudioManager.shared.play(.coin)
    }

    func consumePendingReward() -> Int? {
        defer { pendingReward = nil }
        return pendingReward
    }
}
