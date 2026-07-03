import Foundation
import Combine
import SwiftUI

/// Drives a single play session in any mode: timing, moves, scoring, mode rules.
@MainActor
final class GameSession: ObservableObject, GameSceneDelegate {

    enum Phase { case playing, completed, failed }

    let mode: GameMode
    @Published private(set) var level: LevelDefinition
    @Published var phase: Phase = .playing
    @Published var elapsed: TimeInterval = 0
    @Published var remaining: TimeInterval = 0
    @Published var moves = 0
    @Published var placedPieces = 0
    @Published var round = 1                      // endless / time-attack round
    @Published var sessionScore = 0               // cumulative for arcade modes
    @Published var lastResult: LevelResult?
    @Published var newAchievements: [Achievement] = []
    @Published var hintsRemaining: Int
    @Published var bonusCoins = 0                 // collected pickups this level

    var moveLimit: Int? { mode.hasMoveLimit ? level.parMoves + 1 : nil }

    private var timer: AnyCancellable?
    private var accuracy: Double = 1.0
    private let progress = PlayerProgress.shared
    private let endlessSeed = UInt64.random(in: 0..<UInt64.max)
    var onNextLevel: ((LevelDefinition) -> Void)?

    init(mode: GameMode, level: LevelDefinition) {
        self.mode = mode
        self.level = level
        self.hintsRemaining = mode.allowsHints ? 3 : 0
        if mode == .timeAttack { remaining = 90 }
        startTimer()
    }

    static func start(mode: GameMode, storyLevelID: Int? = nil) -> GameSession {
        let level: LevelDefinition
        switch mode {
        case .story, .hardcore, .relax:
            level = LevelCatalog.shared.level(id: storyLevelID ?? PlayerProgress.shared.highestUnlockedLevel) ?? LevelGenerator.storyLevel(globalID: 1)
        case .dailyChallenge:
            level = LevelGenerator.dailyLevel(for: Date())
        case .endless:
            level = LevelGenerator.endlessLevel(round: 1, seed: UInt64.random(in: 0..<UInt64.max))
        case .timeAttack:
            level = LevelGenerator.timeAttackLevel(round: 1, seed: UInt64.random(in: 0..<UInt64.max))
        }
        return GameSession(mode: mode, level: level)
    }

    private func startTimer() {
        guard mode.hasTimer else { return }
        timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in
                guard let self, self.phase == .playing else { return }
                self.elapsed += 0.1
                if self.mode == .timeAttack {
                    self.remaining -= 0.1
                    if self.remaining <= 0 { self.finishTimeAttack() }
                }
            }
    }

    func useHint() {
        guard hintsRemaining > 0 else { return }
        hintsRemaining -= 1
    }

    // MARK: - GameSceneDelegate

    nonisolated func sceneDidUseMove() {
        Task { @MainActor in
            self.moves += 1
            if let limit = self.moveLimit, self.moves > limit {
                self.fail()
            }
        }
    }

    nonisolated func sceneDidRejectPiece() {}

    nonisolated func sceneDidTouchHazard() {
        Task { @MainActor in
            self.bonusCoins -= 10
            self.progress.coins = max(0, self.progress.coins - 10)
        }
    }

    nonisolated func sceneDidCollectBonus() {
        Task { @MainActor in
            self.bonusCoins += 15
            self.progress.coins += 15
        }
    }

    nonisolated func sceneDidPlacePiece(accuracy: Double, placed: Int, total: Int) {
        Task { @MainActor in
            self.placedPieces = placed
        }
    }

    nonisolated func sceneDidCompleteLevel(accuracy: Double) {
        Task { @MainActor in
            self.accuracy = accuracy
            self.complete()
        }
    }

    // MARK: - Completion

    private func complete() {
        let score = ScoreCalculator.score(level: level, moves: moves, time: elapsed,
                                          accuracy: accuracy, completion: 1.0)
        let rating: ScoreRating = mode == .relax ? .perfect : ScoreRating.from(score: score)
        let coins = ScoreCalculator.coins(for: rating, level: level, streak: progress.perfectStreak)
        let result = LevelResult(levelID: level.id, score: score, rating: rating, stars: rating.stars,
                                 coinsEarned: coins, moves: moves, time: elapsed, date: Date())
        lastResult = result

        switch mode {
        case .story, .hardcore, .relax:
            newAchievements = progress.record(result: result)
            phase = .completed
        case .dailyChallenge:
            progress.dailyCompletions.insert(DailyChallengeService.todayKey())
            progress.coins += coins * 2
            newAchievements = AchievementEngine.evaluate(progress: progress, latest: result)
            GameCenterService.shared.reportDaily(score: score)
            phase = .completed
        case .endless:
            sessionScore += score
            progress.coins += coins
            progress.endlessBest = max(progress.endlessBest, round)
            advanceEndless()
        case .timeAttack:
            sessionScore += 1
            remaining = min(remaining + 6, 90)     // time bonus per solve
            progress.coins += coins
            advanceTimeAttack()
        }
    }

    private func fail() {
        phase = .failed
        progress.perfectStreak = 0
        HapticsManager.shared.error()
        AudioManager.shared.play(.fail)
    }

    private func advanceEndless() {
        round += 1
        level = LevelGenerator.endlessLevel(round: round, seed: endlessSeed)
        resetForNextLevel()
    }

    private func advanceTimeAttack() {
        round += 1
        level = LevelGenerator.timeAttackLevel(round: round, seed: endlessSeed)
        resetForNextLevel()
    }

    private func finishTimeAttack() {
        phase = .completed
        progress.timeAttackBest = max(progress.timeAttackBest, sessionScore)
        GameCenterService.shared.reportTimeAttack(score: sessionScore)
    }

    private func resetForNextLevel() {
        moves = 0
        placedPieces = 0
        elapsed = mode == .timeAttack ? elapsed : 0
        accuracy = 1.0
        onNextLevel?(level)
    }

    func setLevel(_ newLevel: LevelDefinition) {
        level = newLevel
        hintsRemaining = mode.allowsHints ? 3 : 0
        bonusCoins = 0
        lastResult = nil
        newAchievements = []
    }

    func nextStoryLevel() -> LevelDefinition? {
        LevelCatalog.shared.level(id: level.id + 1)
    }
}
