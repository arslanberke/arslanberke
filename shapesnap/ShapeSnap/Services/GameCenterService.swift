import GameKit

/// Game Center: authentication, leaderboards, achievements, friend challenges.
final class GameCenterService: NSObject {
    static let shared = GameCenterService()

    enum LeaderboardID {
        static let stars = "com.shapesnap.lb.stars"
        static let timeAttack = "com.shapesnap.lb.timeattack"
        static let endless = "com.shapesnap.lb.endless"
        static let daily = "com.shapesnap.lb.daily"
    }

    private(set) var isAuthenticated = false

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            if let viewController {
                UIApplication.shared.topViewController?.present(viewController, animated: true)
                return
            }
            self?.isAuthenticated = error == nil && GKLocalPlayer.local.isAuthenticated
        }
    }

    func reportStoryProgress(stars: Int, level: Int) {
        submit(score: stars, leaderboard: LeaderboardID.stars)
    }

    func reportTimeAttack(score: Int) { submit(score: score, leaderboard: LeaderboardID.timeAttack) }
    func reportEndless(round: Int) { submit(score: round, leaderboard: LeaderboardID.endless) }
    func reportDaily(score: Int) { submit(score: score, leaderboard: LeaderboardID.daily) }

    private func submit(score: Int, leaderboard: String) {
        guard isAuthenticated else { return }
        GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local,
                                  leaderboardIDs: [leaderboard]) { _ in }
    }

    func reportAchievement(_ identifier: String, percent: Double = 100) {
        guard isAuthenticated else { return }
        let achievement = GKAchievement(identifier: identifier)
        achievement.percentComplete = percent
        achievement.showsCompletionBanner = true
        GKAchievement.report([achievement]) { _ in }
    }

    func presentLeaderboards() {
        guard isAuthenticated else { return }
        let controller = GKGameCenterViewController(state: .leaderboards)
        controller.gameCenterDelegate = self
        UIApplication.shared.topViewController?.present(controller, animated: true)
    }

    func challengeFriends(score: Int) {
        guard isAuthenticated else { return }
        let controller = GKGameCenterViewController(leaderboardID: LeaderboardID.daily,
                                                    playerScope: .friendsOnly, timeScope: .today)
        controller.gameCenterDelegate = self
        UIApplication.shared.topViewController?.present(controller, animated: true)
    }
}

extension GameCenterService: GKGameCenterControllerDelegate {
    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}

extension UIApplication {
    var topViewController: UIViewController? {
        let scene = connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var top = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
