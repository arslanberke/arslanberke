import SwiftUI
import SpriteKit

struct GameView: View {
    @StateObject var session: GameSession
    @EnvironmentObject var progress: PlayerProgress
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = GameSettings.shared
    @State private var scene: GameScene?
    @State private var sceneID = UUID()
    @State private var introMechanic: Mechanic?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                backgroundGradient.ignoresSafeArea()

                if let scene {
                    SpriteView(scene: scene, options: [.allowsTransparency])
                        .id(sceneID)
                        .ignoresSafeArea()
                        .gesture(TapGesture(count: 2).onEnded { scene.flipActivePiece() })
                        .simultaneousGesture(
                            RotationGesture().onEnded { value in
                                if abs(value.degrees) > 25 { scene.rotateActiveOrNearest() }
                            }
                        )
                }

                VStack {
                    hud
                    Spacer()
                    controls
                }
                .padding(20)

                if session.phase != .playing {
                    ResultsOverlay(session: session,
                                   onNext: goToNextLevel,
                                   onRetry: retry,
                                   onExit: { dismiss() })
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }

                if let mechanic = introMechanic {
                    MechanicIntroOverlay(mechanic: mechanic) {
                        settings.markMechanicSeen(mechanic)
                        withAnimation { introMechanic = nil }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .onAppear { buildScene(size: proxy.size) }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: session.phase == .playing)
    }

    private var backgroundGradient: LinearGradient {
        let theme = Theme.theme(id: progress.selectedTheme)
        return LinearGradient(colors: [theme.boardLight.opacity(0.01), Color(.systemBackground)],
                              startPoint: .top, endPoint: .bottom)
    }

    private var hud: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(.thinMaterial))
            }
            Spacer()
            VStack(spacing: 2) {
                Text(hudTitle).font(.headline)
                HStack(spacing: 10) {
                    if session.mode.hasTimer {
                        Label(timeString, systemImage: "timer")
                    }
                    Label("\(session.moves)\(session.moveLimit.map { "/\($0)" } ?? "")",
                          systemImage: "hand.draw")
                    if !session.level.mechanicSummary.isEmpty {
                        Image(systemName: session.level.mechanicSummary[0].symbolName)
                            .foregroundStyle(.purple)
                    }
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                if session.level.isBoss && session.level.id != LevelCatalog.totalLevels {
                    HStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { index in
                            Image(systemName: index < session.hearts ? "heart.fill" : "heart")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            Spacer()
            if session.mode.allowsHints {
                Button {
                    session.useHint()
                    scene?.showHint()
                } label: {
                    Image(systemName: "lightbulb.fill")
                        .font(.headline)
                        .foregroundStyle(session.hintsRemaining > 0 ? Color.coin : .secondary)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(.thinMaterial))
                        .overlay(alignment: .topTrailing) {
                            Text("\(session.hintsRemaining)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 16, height: 16)
                                .background(Circle().fill(Color.accent))
                        }
                }
                .disabled(session.hintsRemaining == 0)
            } else {
                Color.clear.frame(width: 40, height: 40)
            }
        }
    }

    private var hudTitle: String {
        switch session.mode {
        case .story, .hardcore, .relax:
            return session.level.isBoss ? "⚔️ Boss \(session.level.id)" : "Level \(session.level.id)"
        case .dailyChallenge: return "Daily Challenge"
        case .endless: return "Round \(session.round)"
        case .timeAttack: return "Solved: \(session.sessionScore)"
        }
    }

    private var timeString: String {
        let value = session.mode == .timeAttack ? max(0, session.remaining) : session.elapsed
        return String(format: "%.0fs", value)
    }

    private var controls: some View {
        HStack(spacing: 16) {
            if settings.developerMode && isStoryLike {
                Button { jump(by: -1) } label: {
                    ControlIcon(systemName: "chevron.left", label: "Prev")
                }
            }
            Button { scene?.rotateActiveOrNearest() } label: {
                ControlIcon(systemName: "rotate.right.fill", label: "Rotate")
            }
            if levelNeedsFlip {
                Button { scene?.flipActivePiece() } label: {
                    ControlIcon(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill", label: "Flip")
                }
            }
            if settings.developerMode && isStoryLike {
                Button { jump(by: 1) } label: {
                    ControlIcon(systemName: "chevron.right", label: "Next")
                }
            }
        }
    }

    private var isStoryLike: Bool {
        session.mode == .story || session.mode == .hardcore || session.mode == .relax
    }

    private var levelNeedsFlip: Bool {
        session.level.pieces.contains { !$0.shape.isFlipSymmetric }
    }

    private func jump(by delta: Int) {
        guard isStoryLike, let level = LevelCatalog.shared.level(id: session.level.id + delta) else { return }
        session.phase = .playing
        session.moves = 0
        session.elapsed = 0
        session.placedPieces = 0
        session.setLevel(level)
        buildScene(size: scene?.size ?? .zero)
    }

    private func buildScene(size: CGSize) {
        let theme = Theme.theme(id: progress.selectedTheme)
        let newScene = GameScene(level: session.level, theme: theme,
                                 size: size == .zero ? CGSize(width: 390, height: 844) : size)
        newScene.gameDelegate = session
        scene = newScene
        sceneID = UUID()
        session.onNextLevel = { _ in buildScene(size: size) }
        if let unseen = session.level.mechanicSummary.first(where: { !GameSettings.shared.hasSeenMechanic($0) }) {
            introMechanic = unseen
        }
    }

    private func goToNextLevel() {
        guard let next = session.nextStoryLevel() else { dismiss(); return }
        session.phase = .playing
        session.moves = 0
        session.elapsed = 0
        session.placedPieces = 0
        session.setLevel(next)
        buildScene(size: scene?.size ?? .zero)
    }

    private func retry() {
        session.phase = .playing
        session.moves = 0
        session.elapsed = 0
        session.placedPieces = 0
        session.resetHealth()
        buildScene(size: scene?.size ?? .zero)
    }
}

/// Full-screen card introducing a mechanic the first time it appears,
/// with an animated SF Symbol — zero bundled video/assets.
struct MechanicIntroOverlay: View {
    let mechanic: Mechanic
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 20) {
                Text("New Mechanic!")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Image(systemName: mechanic.symbolName)
                    .font(.system(size: 64, weight: .medium))
                    .foregroundStyle(Color.accent)
                    .symbolEffect(.bounce.up.byLayer, options: .repeating.speed(0.5))
                    .frame(height: 90)
                Text(mechanic.displayName)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text(mechanic.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Let's Go!") { onDismiss() }
                    .buttonStyle(PrimaryButtonStyle())
            }
            .padding(28)
            .frame(maxWidth: 340)
            .card(cornerRadius: 32)
            .padding(24)
        }
    }
}

private struct ControlIcon: View {
    let systemName: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: systemName)
                .font(.title3)
                .frame(width: 56, height: 56)
                .background(Circle().fill(.thinMaterial))
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .foregroundStyle(Color.accent)
    }
}

struct ResultsOverlay: View {
    @ObservedObject var session: GameSession
    let onNext: () -> Void
    let onRetry: () -> Void
    let onExit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 18) {
                if session.phase == .completed, let result = session.lastResult {
                    Text(result.rating.displayName)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    StarRow(stars: result.stars, size: 28)
                    Text("\(result.score)%")
                        .font(.system(size: 52, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.accent)
                        .contentTransition(.numericText())

                    HStack(spacing: 24) {
                        StatChip(label: "Time", value: String(format: "%.1fs", result.time))
                        StatChip(label: "Moves", value: "\(result.moves)")
                        StatChip(label: "Coins", value: "+\(result.coinsEarned)")
                    }

                    if PlayerProgress.shared.perfectStreak > 1 {
                        Label("Perfect streak ×\(PlayerProgress.shared.perfectStreak)!", systemImage: "flame.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.orange)
                    }

                    ForEach(session.newAchievements) { achievement in
                        Label(achievement.name, systemImage: achievement.symbolName)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Capsule().fill(Color.coin.opacity(0.15)))
                            .foregroundStyle(Color.coin)
                    }

                    if session.mode == .timeAttack || session.mode == .endless {
                        Text(session.mode == .timeAttack
                             ? "Puzzles solved: \(session.sessionScore)"
                             : "Reached round \(session.round)")
                            .font(.headline)
                        Button("Done") { onExit() }
                            .buttonStyle(PrimaryButtonStyle())
                    } else {
                        Button("Next Level") { onNext() }
                            .buttonStyle(PrimaryButtonStyle())
                        Button("Replay") { onRetry() }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(failTitle)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text(failSubtitle)
                        .font(.subheadline).foregroundStyle(.secondary)
                    Button("Try Again") { onRetry() }
                        .buttonStyle(PrimaryButtonStyle(color: .red))
                    Button("Exit") { onExit() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(28)
            .frame(maxWidth: 340)
            .card(cornerRadius: 32)
            .padding(24)
        }
    }

    private var failTitle: String {
        if session.failedToBoss { return "The Boss Got You!" }
        return session.mode == .timeAttack ? "Time's Up!" : "Out of Moves"
    }

    private var failSubtitle: String {
        if session.failedToBoss { return "Dodge the projectiles and the sweeping laser." }
        return session.mode == .timeAttack
            ? "Puzzles solved: \(session.sessionScore)"
            : "Hardcore mode allows only \(session.moveLimit ?? 0) moves."
    }
}

private struct StatChip: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.headline.monospacedDigit())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}
