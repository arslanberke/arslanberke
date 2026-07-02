import SwiftUI

/// Purchasable cosmetic theme: board palette, piece style and particles.
struct Theme: Identifiable, Hashable {
    let id: String
    let name: String
    let price: Int                      // coins; 0 = default
    let boardLight: Color
    let boardDark: Color
    let pieceColors: [Color]
    let particleName: String

    static let all: [Theme] = [
        Theme(id: "aurora", name: "Aurora", price: 0,
              boardLight: Color(red: 0.95, green: 0.96, blue: 0.99),
              boardDark: Color(red: 0.09, green: 0.10, blue: 0.14),
              pieceColors: [.blue, .teal, .indigo, .cyan], particleName: "spark"),
        Theme(id: "sunset", name: "Sunset", price: 400,
              boardLight: Color(red: 1.0, green: 0.96, blue: 0.92),
              boardDark: Color(red: 0.14, green: 0.08, blue: 0.10),
              pieceColors: [.orange, .pink, .red, .yellow], particleName: "ember"),
        Theme(id: "forest", name: "Forest", price: 400,
              boardLight: Color(red: 0.93, green: 0.98, blue: 0.93),
              boardDark: Color(red: 0.07, green: 0.12, blue: 0.09),
              pieceColors: [.green, .mint, .teal, .brown], particleName: "leaf"),
        Theme(id: "mono", name: "Monochrome", price: 600,
              boardLight: Color(red: 0.97, green: 0.97, blue: 0.97),
              boardDark: Color(red: 0.10, green: 0.10, blue: 0.10),
              pieceColors: [.gray, .black, .secondary, .primary], particleName: "dot"),
        Theme(id: "neon", name: "Neon Night", price: 900,
              boardLight: Color(red: 0.92, green: 0.92, blue: 0.98),
              boardDark: Color(red: 0.04, green: 0.03, blue: 0.10),
              pieceColors: [.purple, .pink, .cyan, .green], particleName: "glow"),
        Theme(id: "gold", name: "Gilded", price: 1500,
              boardLight: Color(red: 0.99, green: 0.97, blue: 0.90),
              boardDark: Color(red: 0.12, green: 0.10, blue: 0.05),
              pieceColors: [.yellow, .orange, .brown, .red], particleName: "star"),
    ]

    static func theme(id: String) -> Theme { all.first { $0.id == id } ?? all[0] }
}

enum Appearance: String, Codable, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
    var displayName: String { rawValue.capitalized }
}

/// User-configurable settings, persisted via @AppStorage-backed publishing.
final class GameSettings: ObservableObject {
    static let shared = GameSettings()

    @AppStorage("settings.appearance") private var appearanceRaw = Appearance.system.rawValue
    @AppStorage("settings.haptics") var hapticsEnabled = true
    @AppStorage("settings.sound") var soundEnabled = true
    @AppStorage("settings.music") var musicEnabled = true
    @AppStorage("settings.reduceMotion") var reduceMotion = false
    @AppStorage("settings.highContrast") var highContrast = false
    @AppStorage("settings.largePieceHandles") var largePieceHandles = false
    @AppStorage("settings.colorBlindPatterns") var colorBlindPatterns = false

    var appearance: Appearance {
        get { Appearance(rawValue: appearanceRaw) ?? .system }
        set { appearanceRaw = newValue.rawValue; objectWillChange.send() }
    }

    private init() {}
}
