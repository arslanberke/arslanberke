import CoreGraphics
import Foundation

/// Deterministic PRNG so every level is identical on every device / install.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// Builds the full 600-level story catalog plus daily / endless / time-attack levels.
/// Levels are seeded deterministically, then hand-tuned via difficulty curves per world.
enum LevelGenerator {

    static func storyLevel(globalID: Int) -> LevelDefinition {
        let (world, index) = worldAndIndex(for: globalID)
        let seed = UInt64(0x5EED_0000) &+ UInt64(globalID) &* 7919
        return build(id: globalID, world: world.id, index: index, seed: seed,
                     mechanic: mechanicFor(world: world, index: index, seed: seed),
                     difficulty: difficulty(world: world, index: index),
                     isBoss: globalID % 50 == 0,
                     branch: branchFor(world: world, index: index))
    }

    static func dailyLevel(for date: Date) -> LevelDefinition {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        let seed = UInt64(0xDA11_0000) &+ UInt64(day)
        var rng = SeededRandom(seed: seed)
        let mechanics: [Mechanic] = [.none, .rotatingBoard, .gravity, .teleporter, .invisible, .movingTargets, .locked]
        return build(id: -day, world: 0, index: day, seed: seed,
                     mechanic: mechanics.randomElement(using: &rng)!,
                     difficulty: Double.random(in: 0.4...0.8, using: &rng),
                     isBoss: false, branch: nil)
    }

    static func endlessLevel(round: Int, seed: UInt64) -> LevelDefinition {
        var rng = SeededRandom(seed: seed &+ UInt64(round))
        let pool = Mechanic.allCases.filter { $0 != .none && $0 != .multiLayer }
        let mechanic = round < 3 ? Mechanic.none : pool.randomElement(using: &rng)!
        return build(id: -100_000 - round, world: 0, index: round, seed: seed &+ UInt64(round),
                     mechanic: mechanic,
                     difficulty: min(1.0, 0.15 + Double(round) * 0.035),
                     isBoss: round % 10 == 0, branch: nil)
    }

    static func timeAttackLevel(round: Int, seed: UInt64) -> LevelDefinition {
        build(id: -200_000 - round, world: 0, index: round, seed: seed &+ UInt64(round) &* 31,
              mechanic: .none, difficulty: min(0.7, 0.1 + Double(round) * 0.05),
              isBoss: false, branch: nil)
    }

    // MARK: - Internals

    private static func worldAndIndex(for globalID: Int) -> (World, Int) {
        var remaining = globalID
        for world in World.all {
            if remaining <= world.levelCount { return (world, remaining) }
            remaining -= world.levelCount
        }
        return (World.all.last!, remaining)
    }

    /// 0...1 difficulty ramp within each world, with a boss spike at the end.
    private static func difficulty(world: World, index: Int) -> Double {
        let progress = Double(index) / Double(world.levelCount)
        let base = 0.1 + Double(world.id - 1) * 0.07
        return min(1.0, base + progress * 0.45)
    }

    private static func mechanicFor(world: World, index: Int, seed: UInt64) -> Mechanic {
        switch world.id {
        case 1: return .none
        case 2: return .none                       // multiple pieces handled by piece count
        case 10:                                    // mixed mechanics world
            var rng = SeededRandom(seed: seed)
            let pool = Mechanic.allCases.filter { $0 != .none }
            return index <= 5 ? .none : pool.randomElement(using: &rng)!
        default:
            // introduce each world's mechanic gradually: first few levels classic
            return index <= 3 ? .none : world.mechanic
        }
    }

    private static func branchFor(world: World, index: Int) -> BranchPath? {
        guard world.hasBranch, index > world.levelCount - 10 else { return nil }
        // last 10 levels of branching worlds split: odd = calm, even = master
        return index % 2 == 0 ? .hard : .easy
    }

    private static func build(id: Int, world: Int, index: Int, seed: UInt64,
                              mechanic: Mechanic, difficulty: Double,
                              isBoss: Bool, branch: BranchPath?) -> LevelDefinition {
        var rng = SeededRandom(seed: seed)
        let pieceCount = pieceCount(world: world, difficulty: difficulty, isBoss: isBoss, rng: &rng)
        let allowRotation = world != 1 && world != 2 || difficulty > 0.35
        let allowFlip = world == 4 || (world >= 7 && difficulty > 0.5) || world == 0

        var pieces: [PieceDefinition] = []
        var usedTargets: [CGPoint] = []
        for pieceIndex in 0..<pieceCount {
            let shape = shapePool(difficulty: difficulty).randomElement(using: &rng)!
            let size = CGFloat(Double.random(in: 0.16...0.30, using: &rng)) * (isBoss ? 0.85 : 1.0)
            let target = placeTarget(avoiding: usedTargets, size: size, rng: &rng)
            usedTargets.append(target)

            let targetRotation = allowRotation ? Int.random(in: 0...3, using: &rng) : 0
            let targetFlipped = allowFlip && Bool.random(using: &rng)

            var pieceMechanics: [Mechanic] = []
            if mechanic == .frozen || mechanic == .locked || mechanic == .invisible ||
                mechanic == .magnetic || mechanic == .shapeShifting {
                // apply piece-level mechanics to roughly half the pieces
                if pieceIndex % 2 == 0 || pieceCount == 1 { pieceMechanics.append(mechanic) }
            }

            pieces.append(PieceDefinition(
                id: pieceIndex,
                shape: shape,
                size: size,
                targetPosition: target,
                targetRotation: targetRotation,
                targetFlipped: targetFlipped,
                spawnPosition: CGPoint(x: CGFloat(Double.random(in: 0.15...0.85, using: &rng)),
                                       y: CGFloat(Double.random(in: 0.05...0.16, using: &rng))),
                spawnRotation: allowRotation ? Int.random(in: 0...3, using: &rng) : 0,
                spawnFlipped: false,
                mechanics: pieceMechanics,
                layer: mechanic == .multiLayer ? pieceIndex % 2 : 0
            ))
        }

        var boardMechanics: [Mechanic] = []
        if [.rotatingBoard, .gravity, .mirrorControls, .darkness, .movingTargets, .teleporter, .multiLayer].contains(mechanic) {
            boardMechanics.append(mechanic)
        }

        var portals: [PortalPair] = []
        if mechanic == .teleporter {
            portals.append(PortalPair(
                entry: CGPoint(x: CGFloat(Double.random(in: 0.15...0.4, using: &rng)),
                               y: CGFloat(Double.random(in: 0.3...0.5, using: &rng))),
                exit: CGPoint(x: CGFloat(Double.random(in: 0.6...0.85, using: &rng)),
                              y: CGFloat(Double.random(in: 0.55...0.8, using: &rng)))))
        }

        let extraMoves = pieces.reduce(0) { $0 + ($1.requiresRotation ? 1 : 0) + ($1.requiresFlip ? 1 : 0) }
        let parMoves = pieceCount + extraMoves + (isBoss ? 2 : 1)
        let parTime = TimeInterval(6 + pieceCount * 5) * (isBoss ? 0.7 : 1.0) * (1.0 + difficulty * 0.5)

        return LevelDefinition(id: id, world: world, indexInWorld: index, seed: seed,
                               pieces: pieces, boardMechanics: boardMechanics, portals: portals,
                               parMoves: parMoves, parTime: parTime, isBoss: isBoss, branch: branch)
    }

    private static func pieceCount(world: Int, difficulty: Double, isBoss: Bool, rng: inout SeededRandom) -> Int {
        if isBoss { return Int.random(in: 4...6, using: &rng) }
        switch world {
        case 1: return 1
        case 2: return Int.random(in: 2...4, using: &rng)
        default: return max(1, min(5, 1 + Int(difficulty * 4) + Int.random(in: 0...1, using: &rng)))
        }
    }

    private static func shapePool(difficulty: Double) -> [PieceShape] {
        if difficulty < 0.2 { return [.square, .rectangle, .triangle, .diamond] }
        if difficulty < 0.45 { return [.square, .triangle, .rightTriangle, .diamond, .hexagon, .trapezoid, .pentagon] }
        return PieceShape.allCases
    }

    private static func placeTarget(avoiding used: [CGPoint], size: CGFloat, rng: inout SeededRandom) -> CGPoint {
        for _ in 0..<40 {
            let candidate = CGPoint(x: CGFloat(Double.random(in: 0.2...0.8, using: &rng)),
                                    y: CGFloat(Double.random(in: 0.35...0.85, using: &rng)))
            let tooClose = used.contains { hypot($0.x - candidate.x, $0.y - candidate.y) < size * 1.1 }
            if !tooClose { return candidate }
        }
        return CGPoint(x: 0.5, y: 0.6)
    }
}

/// Cached access to the full story catalog.
final class LevelCatalog {
    static let shared = LevelCatalog()
    static let totalLevels = 600

    private var cache: [Int: LevelDefinition] = [:]
    private let lock = NSLock()

    func level(id: Int) -> LevelDefinition? {
        guard (1...LevelCatalog.totalLevels).contains(id) else { return nil }
        lock.lock(); defer { lock.unlock() }
        if let cached = cache[id] { return cached }
        let level = LevelGenerator.storyLevel(globalID: id)
        cache[id] = level
        return level
    }

    func levels(world: World) -> [LevelDefinition] {
        let start = world.firstLevelID
        return (start..<(start + world.levelCount)).compactMap { level(id: $0) }
    }
}
