import CoreGraphics
import Foundation

/// A special mechanic applied to a level or an individual piece.
enum Mechanic: String, Codable, CaseIterable, Identifiable {
    case none
    case rotatingBoard      // the entire board rotates every few seconds
    case gravity            // pieces fall naturally
    case frozen             // pieces can only be moved once
    case locked             // pieces must be unlocked first
    case teleporter         // pieces travel between portals
    case magnetic           // pieces attract each other
    case mirrorControls     // controls are reversed
    case invisible          // pieces become visible only temporarily
    case shapeShifting      // pieces change form periodically
    case multiLayer         // stacked puzzle layers
    case movingTargets      // target sockets drift continuously
    case darkness           // board is dark, revealed near the finger

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "Classic"
        case .rotatingBoard: return "Rotating Board"
        case .gravity: return "Gravity"
        case .frozen: return "Frozen Pieces"
        case .locked: return "Locked Pieces"
        case .teleporter: return "Teleporters"
        case .magnetic: return "Magnetic Pieces"
        case .mirrorControls: return "Mirror World"
        case .invisible: return "Invisible Pieces"
        case .shapeShifting: return "Shape Shifters"
        case .multiLayer: return "Multi-Layer"
        case .movingTargets: return "Moving Targets"
        case .darkness: return "Darkness"
        }
    }

    var symbolName: String {
        switch self {
        case .none: return "square.on.square"
        case .rotatingBoard: return "arrow.triangle.2.circlepath"
        case .gravity: return "arrow.down.circle"
        case .frozen: return "snowflake"
        case .locked: return "lock.fill"
        case .teleporter: return "circle.dotted.circle"
        case .magnetic: return "bolt.horizontal.circle"
        case .mirrorControls: return "arrow.left.arrow.right"
        case .invisible: return "eye.slash"
        case .shapeShifting: return "wand.and.stars"
        case .multiLayer: return "square.3.layers.3d"
        case .movingTargets: return "scope"
        case .darkness: return "moon.fill"
        }
    }
}

/// Geometric archetype of a puzzle piece. Points are normalized to a unit square.
enum PieceShape: String, Codable, CaseIterable {
    case square, rectangle, triangle, rightTriangle, diamond, hexagon,
         pentagon, lShape, tShape, zShape, chevron, star, notchedSquare, trapezoid

    /// Polygon vertices in unit space (0...1).
    var unitPoints: [CGPoint] {
        switch self {
        case .square:
            return [.init(x: 0, y: 0), .init(x: 1, y: 0), .init(x: 1, y: 1), .init(x: 0, y: 1)]
        case .rectangle:
            return [.init(x: 0, y: 0.2), .init(x: 1, y: 0.2), .init(x: 1, y: 0.8), .init(x: 0, y: 0.8)]
        case .triangle:
            return [.init(x: 0.5, y: 0), .init(x: 1, y: 1), .init(x: 0, y: 1)]
        case .rightTriangle:
            return [.init(x: 0, y: 0), .init(x: 1, y: 1), .init(x: 0, y: 1)]
        case .diamond:
            return [.init(x: 0.5, y: 0), .init(x: 1, y: 0.5), .init(x: 0.5, y: 1), .init(x: 0, y: 0.5)]
        case .hexagon:
            return [.init(x: 0.25, y: 0), .init(x: 0.75, y: 0), .init(x: 1, y: 0.5),
                    .init(x: 0.75, y: 1), .init(x: 0.25, y: 1), .init(x: 0, y: 0.5)]
        case .pentagon:
            return [.init(x: 0.5, y: 0), .init(x: 1, y: 0.38), .init(x: 0.81, y: 1),
                    .init(x: 0.19, y: 1), .init(x: 0, y: 0.38)]
        case .lShape:
            return [.init(x: 0, y: 0), .init(x: 0.5, y: 0), .init(x: 0.5, y: 0.5),
                    .init(x: 1, y: 0.5), .init(x: 1, y: 1), .init(x: 0, y: 1)]
        case .tShape:
            return [.init(x: 0, y: 0), .init(x: 1, y: 0), .init(x: 1, y: 0.4),
                    .init(x: 0.7, y: 0.4), .init(x: 0.7, y: 1), .init(x: 0.3, y: 1), .init(x: 0.3, y: 0.4), .init(x: 0, y: 0.4)]
        case .zShape:
            return [.init(x: 0, y: 0), .init(x: 0.6, y: 0), .init(x: 0.6, y: 0.5),
                    .init(x: 1, y: 0.5), .init(x: 1, y: 1), .init(x: 0.4, y: 1), .init(x: 0.4, y: 0.5), .init(x: 0, y: 0.5)]
        case .chevron:
            return [.init(x: 0, y: 0), .init(x: 0.5, y: 0.4), .init(x: 1, y: 0),
                    .init(x: 1, y: 0.6), .init(x: 0.5, y: 1), .init(x: 0, y: 0.6)]
        case .star:
            return [.init(x: 0.5, y: 0), .init(x: 0.63, y: 0.35), .init(x: 1, y: 0.38),
                    .init(x: 0.72, y: 0.62), .init(x: 0.81, y: 1), .init(x: 0.5, y: 0.78),
                    .init(x: 0.19, y: 1), .init(x: 0.28, y: 0.62), .init(x: 0, y: 0.38), .init(x: 0.37, y: 0.35)]
        case .notchedSquare:
            return [.init(x: 0, y: 0), .init(x: 1, y: 0), .init(x: 1, y: 1),
                    .init(x: 0.65, y: 1), .init(x: 0.65, y: 0.6), .init(x: 0.35, y: 0.6), .init(x: 0.35, y: 1), .init(x: 0, y: 1)]
        case .trapezoid:
            return [.init(x: 0.25, y: 0), .init(x: 0.75, y: 0), .init(x: 1, y: 1), .init(x: 0, y: 1)]
        }
    }
}

/// One puzzle piece within a level.
struct PieceDefinition: Codable, Identifiable, Hashable {
    var id: Int
    var shape: PieceShape
    var size: CGFloat                 // side length in normalized board units (0...1)
    /// Target center position on the board, normalized (0...1).
    var targetPosition: CGPoint
    /// Target rotation in quarter turns (0-3).
    var targetRotation: Int
    /// Whether the piece must be flipped horizontally to fit.
    var targetFlipped: Bool
    /// Spawn position in the tray area, normalized.
    var spawnPosition: CGPoint
    var spawnRotation: Int
    var spawnFlipped: Bool
    var mechanics: [Mechanic]
    /// Layer index for multi-layer puzzles (0 = bottom).
    var layer: Int

    var requiresRotation: Bool { targetRotation != spawnRotation }
    var requiresFlip: Bool { targetFlipped != spawnFlipped }
}

/// A pair of portals for teleporter levels, normalized coordinates.
struct PortalPair: Codable, Hashable {
    var entry: CGPoint
    var exit: CGPoint
}

/// Fully describes a single playable level.
struct LevelDefinition: Codable, Identifiable, Hashable {
    var id: Int                       // global level number, 1-based
    var world: Int
    var indexInWorld: Int             // 1-based within the world
    var seed: UInt64
    var pieces: [PieceDefinition]
    var boardMechanics: [Mechanic]
    var portals: [PortalPair]
    var parMoves: Int                 // moves for a Perfect rating
    var parTime: TimeInterval         // seconds for full time bonus
    var isBoss: Bool
    var branch: BranchPath?

    var mechanicSummary: [Mechanic] {
        var set = Set(boardMechanics)
        pieces.forEach { set.formUnion($0.mechanics) }
        set.remove(.none)
        return Array(set).sorted { $0.rawValue < $1.rawValue }
    }
}

/// Branching path choice offered at the end of some worlds.
enum BranchPath: String, Codable, CaseIterable {
    case easy, hard

    var displayName: String { self == .easy ? "Calm Path" : "Master Path" }
    var rewardMultiplier: Double { self == .easy ? 1.0 : 2.0 }
    var symbolName: String { self == .easy ? "leaf.fill" : "flame.fill" }
}
