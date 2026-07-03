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
        case 10:
            // Gauntlet: gentle re-introduction, then a curated escalation so the
            // final world feels designed rather than random.
            var rng = SeededRandom(seed: seed)
            switch index {
            case ...5: return .none
            case ...20:   // one familiar mechanic at a time
                return [Mechanic.rotatingBoard, .gravity, .locked, .teleporter,
                        .invisible, .movingTargets].randomElement(using: &rng)!
            case ...50:   // trickier board mechanics join the pool
                return [Mechanic.rotatingBoard, .gravity, .teleporter, .mirrorControls,
                        .movingTargets, .darkness, .magnetic].randomElement(using: &rng)!
            default:      // final stretch: anything goes
                return Mechanic.allCases.filter { $0 != .none && $0 != .frozen }.randomElement(using: &rng)!
            }
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
        // Pulsing timing mechanic appears alongside obstacles in later content.
        let pulsing = (world >= 5 || world == 0) && difficulty > 0.45 && index % 4 == 0
        // Decide up-front whether this level has obstacle bars so targets can be
        // pushed to the top of the board, keeping bars between spawn and target.
        let hasObstacles = (world == 1 && index > 10) || (world == 10 && index % 5 != 1)
            || (world != 1 && world != 10 && difficulty > 0.4 && index % 2 == 0)

        var pieces: [PieceDefinition] = []
        var usedTargets: [CGPoint] = []
        for pieceIndex in 0..<pieceCount {
            // When a flip is called for, force a chiral shape so the mirrored
            // silhouette is visually distinguishable — flips on symmetric shapes
            // are meaningless.
            let wantsFlip = allowFlip && Bool.random(using: &rng)
            let shape = wantsFlip
                ? [PieceShape.rightTriangle, .lShape, .zShape].randomElement(using: &rng)!
                : shapePool(difficulty: difficulty).randomElement(using: &rng)!
            let size = CGFloat(Double.random(in: 0.16...0.30, using: &rng)) * (isBoss ? 0.85 : 1.0)
            let target = placeTarget(avoiding: usedTargets, size: size,
                                     yRange: hasObstacles ? 0.6...0.88 : 0.35...0.85, rng: &rng)
            usedTargets.append(target)

            let targetRotation = allowRotation ? Int.random(in: 0...3, using: &rng) : 0
            let targetFlipped = wantsFlip

            var pieceMechanics: [Mechanic] = []
            if mechanic == .locked || mechanic == .invisible ||
                mechanic == .magnetic || mechanic == .shapeShifting {
                // apply piece-level mechanics to roughly half the pieces
                if pieceIndex % 2 == 0 || pieceCount == 1 { pieceMechanics.append(mechanic) }
            }
            if pulsing { pieceMechanics.append(.pulsing) }
            // World 10 finale: layer a second piece mechanic on top from level 40.
            if world == 10 && index > 40 && pieceIndex % 2 == 1 {
                let extra = [Mechanic.invisible, .pulsing].randomElement(using: &rng)!
                if !pieceMechanics.contains(extra) { pieceMechanics.append(extra) }
            }

            pieces.append(PieceDefinition(
                id: pieceIndex,
                shape: shape,
                size: size,
                targetPosition: target,
                targetRotation: targetRotation,
                targetFlipped: targetFlipped,
                spawnPosition: traySlot(index: pieceIndex, count: pieceCount, rng: &rng),
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

        let obstacles = makeObstacles(world: world, index: index, difficulty: difficulty,
                                      targets: usedTargets, pieces: pieces, rng: &rng)

        var collectibles: [CGPoint] = []
        if index > 15 && index % 3 == 0 {
            for _ in 0..<Int.random(in: 1...2, using: &rng) {
                for _ in 0..<20 {   // keep pickups off the obstacle bars
                    let candidate = CGPoint(x: CGFloat(Double.random(in: 0.15...0.85, using: &rng)),
                                            y: CGFloat(Double.random(in: 0.3...0.8, using: &rng)))
                    let clear = obstacles.allSatisfy { !$0.rect.insetBy(dx: -0.05, dy: -0.05).contains(candidate) }
                    if clear {
                        collectibles.append(candidate)
                        break
                    }
                }
            }
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
                               obstacles: obstacles, collectibles: collectibles,
                               parMoves: parMoves, parTime: parTime, isBoss: isBoss, branch: branch)
    }

    /// Thin bars the player must slide pieces around, always confined to the
    /// board area and kept clear of target sockets. In World 1 they appear from
    /// level 11 (after the pure-drag tutorial) and grow in number; later worlds
    /// sprinkle them in at higher difficulty. Some levels form a zigzag corridor
    /// with alternating gaps so the piece must travel a winding path.
    private static func makeObstacles(world: Int, index: Int, difficulty: Double,
                                      targets: [CGPoint], pieces: [PieceDefinition],
                                      rng: inout SeededRandom) -> [Obstacle] {
        let barRows: Int
        var corridor = false
        if world == 1 {
            guard index > 10 else { return [] }
            barRows = min(3, 1 + (index - 11) / 15)
            corridor = index >= 25 && index % 5 == 0
        } else if world == 10 {
            // Gauntlet: obstacles on almost every level, ramping in density.
            guard index % 5 != 1 else { return [] }   // occasional breather
            barRows = min(4, 1 + index / 25)
            corridor = index % 4 == 0
        } else {
            guard difficulty > 0.4, index % 2 == 0 else { return [] }
            barRows = Int.random(in: 1...2, using: &rng)
            corridor = index % 6 == 0
        }

        let board = BoardLayout.rect
        let maxPieceSize = pieces.map(\.size).max() ?? 0.2
        // approximate piece extents in scene-normalized units
        let pieceW = maxPieceSize * board.width * 0.75
        let pieceH = maxPieceSize * board.height * 0.75
        // targets are board-normalized; convert to scene-normalized
        let sceneTargets = targets.map {
            CGPoint(x: board.minX + $0.x * board.width, y: board.minY + $0.y * board.height)
        }
        let thickness: CGFloat = 0.018
        // Gaps fit the piece at ANY rotation (diagonal + comfortable margin) —
        // rotation is a placement mechanic, never a squeeze-through puzzle.
        let gapWidth = max(pieceW * 2.1, 0.26)
        // Bars must sit between the spawn tray (bottom) and the lowest target,
        // like hurdles between the start and the finish line.
        let lowestTargetY = sceneTargets.map(\.y).min() ?? board.maxY
        let bandBottom = board.minY + 0.03
        let bandTop = lowestTargetY - pieceH * 0.9
        guard bandTop - bandBottom > 0.04 else { return [] }

        func row(y: CGFloat, gapCenter: CGFloat, hazard: Bool = false) -> [Obstacle] {
            var bars: [Obstacle] = []
            let leftEnd = max(board.minX, gapCenter - gapWidth / 2)
            let rightStart = min(board.maxX, gapCenter + gapWidth / 2)
            if leftEnd - board.minX > 0.03 {
                bars.append(Obstacle(center: CGPoint(x: (board.minX + leftEnd) / 2, y: y),
                                     size: CGSize(width: leftEnd - board.minX, height: thickness),
                                     isHazard: hazard))
            }
            if board.maxX - rightStart > 0.03 {
                bars.append(Obstacle(center: CGPoint(x: (rightStart + board.maxX) / 2, y: y),
                                     size: CGSize(width: board.maxX - rightStart, height: thickness),
                                     isHazard: hazard))
            }
            return bars
        }

        // From mid-World-1 on, some rows become hazards: they don't block but
        // cost coins on contact.
        let hazardAllowed = (world == 1 && index > 20) || world != 1

        var obstacles: [Obstacle] = []

        // Rows must be far enough apart vertically that the piece fits BETWEEN
        // them at any rotation — otherwise zigzag paths become impassable.
        let rowSpacing = max(0.1, pieceH * 2.0)

        if corridor {
            // Alternating gaps (left, right, left) force a winding path upward.
            let rows = max(1, min(3, Int((bandTop - bandBottom) / rowSpacing)))
            for i in 0..<rows {
                let y = bandBottom + (bandTop - bandBottom) * (CGFloat(i) + 0.5) / CGFloat(rows)
                let gapCenter = i % 2 == 0 ? board.minX + board.width * 0.2
                                           : board.maxX - board.width * 0.2
                let hazard = hazardAllowed && Double.random(in: 0...1, using: &rng) < 0.35
                obstacles += row(y: y, gapCenter: gapCenter, hazard: hazard)
            }
            return sanitize(obstacles, board: board, sceneTargets: sceneTargets,
                            pieceW: pieceW, pieceH: pieceH)
        }

        for _ in 0..<barRows {
            for _ in 0..<25 {   // find a bar row inside the band, clear of other bars
                let y = bandBottom + (bandTop - bandBottom) * CGFloat(Double.random(in: 0...1, using: &rng))
                let gapCenter = board.minX + board.width * CGFloat(Double.random(in: 0.2...0.8, using: &rng))
                if obstacles.allSatisfy({ abs($0.center.y - y) > rowSpacing }) {
                    let hazard = hazardAllowed && Double.random(in: 0...1, using: &rng) < 0.35
                    obstacles += row(y: y, gapCenter: gapCenter, hazard: hazard)
                    break
                }
            }
        }

        // Later content also gets a vertical bar with a gap, making the field a maze.
        if (world == 10 || difficulty > 0.65) && bandTop - bandBottom > 0.12 && Bool.random(using: &rng) {
            let x = board.minX + board.width * CGFloat(Double.random(in: 0.3...0.7, using: &rng))
            let gapH = max(pieceH * 2.1, 0.18)
            let gapCenterY = bandBottom + (bandTop - bandBottom) * CGFloat(Double.random(in: 0.3...0.7, using: &rng))
            let bottomEnd = max(bandBottom, gapCenterY - gapH / 2)
            let topStart = min(bandTop, gapCenterY + gapH / 2)
            let hazard = hazardAllowed && Double.random(in: 0...1, using: &rng) < 0.35
            if bottomEnd - bandBottom > 0.03 {
                obstacles.append(Obstacle(center: CGPoint(x: x, y: (bandBottom + bottomEnd) / 2),
                                          size: CGSize(width: 0.035, height: bottomEnd - bandBottom),
                                          isHazard: hazard))
            }
            if bandTop - topStart > 0.03 {
                obstacles.append(Obstacle(center: CGPoint(x: x, y: (topStart + bandTop) / 2),
                                          size: CGSize(width: 0.035, height: bandTop - topStart),
                                          isHazard: hazard))
            }
        }
        return sanitize(obstacles, board: board, sceneTargets: sceneTargets,
                        pieceW: pieceW, pieceH: pieceH)
    }

    /// Safety net: clamp every bar inside the board and drop any bar that would
    /// crowd a target socket, no matter how it was generated.
    private static func sanitize(_ obstacles: [Obstacle], board: CGRect, sceneTargets: [CGPoint],
                                 pieceW: CGFloat, pieceH: CGFloat) -> [Obstacle] {
        obstacles.compactMap { obstacle in
            var rect = obstacle.rect.intersection(board.insetBy(dx: 0.005, dy: 0.005))
            guard !rect.isNull, rect.width > 0.02, rect.height > 0.008 else { return nil }
            rect = rect.standardized
            let clearance = rect.insetBy(dx: -pieceW * 0.7, dy: -pieceH * 0.7)
            guard sceneTargets.allSatisfy({ !clearance.contains($0) }) else { return nil }
            return Obstacle(center: CGPoint(x: rect.midX, y: rect.midY),
                            size: rect.size, isHazard: obstacle.isHazard)
        }
    }

    /// Evenly-spaced tray slots so waiting pieces never pile on top of each
    /// other (or on the Rotate/Flip buttons); rows alternate in height.
    private static func traySlot(index: Int, count: Int, rng: inout SeededRandom) -> CGPoint {
        let span = 0.8 - 0.14
        let x = count == 1
            ? Double.random(in: 0.3...0.7, using: &rng)
            : 0.14 + span * Double(index) / Double(count - 1)
        let y = index % 2 == 0 ? 0.19 : 0.135
        return CGPoint(x: CGFloat(x + Double.random(in: -0.015...0.015, using: &rng)), y: CGFloat(y))
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

    private static func placeTarget(avoiding used: [CGPoint], size: CGFloat,
                                    yRange: ClosedRange<Double>, rng: inout SeededRandom) -> CGPoint {
        for _ in 0..<40 {
            let candidate = CGPoint(x: CGFloat(Double.random(in: 0.2...0.8, using: &rng)),
                                    y: CGFloat(Double.random(in: yRange, using: &rng)))
            let tooClose = used.contains { hypot($0.x - candidate.x, $0.y - candidate.y) < size * 1.1 }
            if !tooClose { return candidate }
        }
        return CGPoint(x: 0.5, y: (yRange.lowerBound + yRange.upperBound) / 2)
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
