import Foundation

enum GameMode: String, Codable, CaseIterable, Identifiable {
    case story, timeAttack, dailyChallenge, endless, hardcore, relax

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .story: return "Story"
        case .timeAttack: return "Time Attack"
        case .dailyChallenge: return "Daily Challenge"
        case .endless: return "Endless"
        case .hardcore: return "Hardcore"
        case .relax: return "Relax"
        }
    }

    var subtitle: String {
        switch self {
        case .story: return "600 handcrafted levels across 10 worlds"
        case .timeAttack: return "Solve as many puzzles as you can in 90 seconds"
        case .dailyChallenge: return "A new puzzle every day"
        case .endless: return "Infinite puzzles, rising difficulty"
        case .hardcore: return "No hints. Limited moves."
        case .relax: return "No timer. Just vibes."
        }
    }

    var symbolName: String {
        switch self {
        case .story: return "map.fill"
        case .timeAttack: return "timer"
        case .dailyChallenge: return "calendar"
        case .endless: return "infinity"
        case .hardcore: return "flame.fill"
        case .relax: return "moon.stars.fill"
        }
    }

    var hasTimer: Bool { self != .relax }
    var allowsHints: Bool { self != .hardcore }
    var hasMoveLimit: Bool { self == .hardcore }
}

/// Static description of one of the ten story worlds.
struct World: Identifiable, Hashable {
    let id: Int
    let name: String
    let tagline: String
    let levelCount: Int
    let mechanic: Mechanic
    let paletteIndex: Int
    let hasBranch: Bool

    static let all: [World] = [
        World(id: 1, name: "First Steps", tagline: "Learn the ropes", levelCount: 50, mechanic: .none, paletteIndex: 0, hasBranch: false),
        World(id: 2, name: "Pieces Apart", tagline: "Multiple missing pieces", levelCount: 50, mechanic: .none, paletteIndex: 1, hasBranch: false),
        World(id: 3, name: "Spin Cycle", tagline: "Rotation mechanics", levelCount: 50, mechanic: .rotatingBoard, paletteIndex: 2, hasBranch: true),
        World(id: 4, name: "Looking Glass", tagline: "Mirror puzzles", levelCount: 50, mechanic: .mirrorControls, paletteIndex: 3, hasBranch: false),
        World(id: 5, name: "Drift", tagline: "Moving pieces", levelCount: 50, mechanic: .movingTargets, paletteIndex: 4, hasBranch: true),
        World(id: 6, name: "Freefall", tagline: "Gravity puzzles", levelCount: 50, mechanic: .gravity, paletteIndex: 5, hasBranch: false),
        World(id: 7, name: "Under Lock", tagline: "Locked pieces", levelCount: 50, mechanic: .locked, paletteIndex: 6, hasBranch: true),
        World(id: 8, name: "Wormholes", tagline: "Teleport mechanics", levelCount: 50, mechanic: .teleporter, paletteIndex: 7, hasBranch: false),
        World(id: 9, name: "Lights Out", tagline: "Darkness and hidden pieces", levelCount: 50, mechanic: .darkness, paletteIndex: 8, hasBranch: true),
        World(id: 10, name: "The Gauntlet", tagline: "Everything, everywhere", levelCount: 100, mechanic: .none, paletteIndex: 9, hasBranch: false),
    ]

    /// Global level id of this world's first level.
    var firstLevelID: Int {
        World.all.prefix(while: { $0.id < id }).reduce(1) { $0 + $1.levelCount }
    }
}
