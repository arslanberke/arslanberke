import Foundation

enum ScoreRating: String, Codable, CaseIterable {
    case perfect, excellent, good, failed

    static func from(score: Int) -> ScoreRating {
        switch score {
        case 100...: return .perfect
        case 90...99: return .excellent
        case 70...89: return .good
        default: return .failed
        }
    }

    var displayName: String {
        switch self {
        case .perfect: return "Perfect"
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .failed: return "Try Again"
        }
    }

    var stars: Int {
        switch self {
        case .perfect: return 3
        case .excellent: return 2
        case .good: return 1
        case .failed: return 0
        }
    }
}

/// Computes the 0-100 score for a completed level.
struct ScoreCalculator {
    /// - Parameters:
    ///   - accuracy: mean placement accuracy 0...1 (1 = every piece snapped dead-center)
    ///   - completion: fraction of pieces correctly placed 0...1
    static func score(level: LevelDefinition,
                      moves: Int,
                      time: TimeInterval,
                      accuracy: Double,
                      completion: Double) -> Int {
        guard completion >= 1.0 else { return Int(completion * 60) }
        let movePenalty = max(0, moves - level.parMoves)
        let moveScore = max(0.0, 1.0 - Double(movePenalty) * 0.08)
        let timeScore = time <= level.parTime ? 1.0 : max(0.0, 1.0 - (time - level.parTime) / (level.parTime * 2))
        let raw = 40.0 * moveScore + 30.0 * timeScore + 30.0 * accuracy
        return min(100, Int(raw.rounded()))
    }

    static func coins(for rating: ScoreRating, level: LevelDefinition, streak: Int) -> Int {
        let base: Int
        switch rating {
        case .perfect: base = 25
        case .excellent: base = 15
        case .good: base = 8
        case .failed: return 0
        }
        let bossBonus = level.isBoss ? 3 : 1
        let branchMult = level.branch?.rewardMultiplier ?? 1.0
        let comboBonus = min(streak, 10) * 2
        return Int(Double(base * bossBonus) * branchMult) + comboBonus
    }
}

struct LevelResult: Codable, Hashable {
    var levelID: Int
    var score: Int
    var rating: ScoreRating
    var stars: Int
    var coinsEarned: Int
    var moves: Int
    var time: TimeInterval
    var date: Date
}
