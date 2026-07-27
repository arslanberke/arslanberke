import SwiftUI

struct WorldMapView: View {
    @EnvironmentObject var progress: PlayerProgress

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(World.all) { world in
                    WorldCard(world: world,
                              unlocked: progress.highestUnlockedLevel >= world.firstLevelID,
                              starsEarned: starsEarned(in: world),
                              chosenBranch: progress.branchChoices[world.id])
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Worlds")
        .navigationBarTitleDisplayMode(.large)
    }

    private func starsEarned(in world: World) -> Int {
        (world.firstLevelID..<(world.firstLevelID + world.levelCount))
            .reduce(0) { $0 + progress.stars(for: $1) }
    }
}

private struct WorldCard: View {
    let world: World
    let unlocked: Bool
    let starsEarned: Int
    let chosenBranch: BranchPath?

    private static let gradients: [[Color]] = [
        [.blue, .cyan], [.teal, .green], [.orange, .yellow], [.purple, .pink],
        [.indigo, .blue], [.mint, .teal], [.red, .orange], [.cyan, .indigo],
        [.gray, .black], [.pink, .purple],
    ]

    var body: some View {
        NavigationLink {
            LevelGridView(world: world)
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LinearGradient(colors: Self.gradients[world.paletteIndex],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 58, height: 58)
                    Image(systemName: unlocked ? world.mechanic.symbolName : "lock.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("World \(world.id) · \(world.name)")
                        .font(.headline)
                        .foregroundStyle(unlocked ? .primary : .secondary)
                    Text(world.tagline)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Label("\(starsEarned)/\(world.levelCount * 3)", systemImage: "star.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.coin)
                        if world.hasBranch {
                            Label(chosenBranch?.displayName ?? "Branching paths",
                                  systemImage: chosenBranch?.symbolName ?? "arrow.triangle.branch")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.purple)
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .card(cornerRadius: 22)
            .opacity(unlocked ? 1 : 0.6)
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
    }
}

struct LevelGridView: View {
    let world: World
    @EnvironmentObject var progress: PlayerProgress
    @State private var showBranchChoice = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(0..<world.levelCount, id: \.self) { offset in
                    let levelID = world.firstLevelID + offset
                    let level = LevelCatalog.shared.level(id: levelID)
                    LevelCell(levelID: levelID,
                              indexInWorld: offset + 1,
                              stars: progress.stars(for: levelID),
                              unlocked: progress.isUnlocked(levelID),
                              isBoss: level?.isBoss == true,
                              branch: level?.branch)
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(world.name)
        .toolbar {
            if world.hasBranch {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showBranchChoice = true } label: {
                        Image(systemName: "arrow.triangle.branch")
                    }
                }
            }
        }
        .confirmationDialog("Choose your path for the final stretch", isPresented: $showBranchChoice, titleVisibility: .visible) {
            Button("Calm Path — easier levels, standard rewards") {
                progress.branchChoices[world.id] = .easy
            }
            Button("Master Path — harder levels, 2× rewards + exclusive theme") {
                progress.branchChoices[world.id] = .hard
            }
        }
    }
}

private struct LevelCell: View {
    let levelID: Int
    let indexInWorld: Int
    let stars: Int
    let unlocked: Bool
    let isBoss: Bool
    let branch: BranchPath?

    var body: some View {
        NavigationLink {
            GameView(session: GameSession.start(mode: .story, storyLevelID: levelID))
        } label: {
            VStack(spacing: 4) {
                if isBoss {
                    Image(systemName: "crown.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Text(unlocked ? "\(indexInWorld)" : "")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .overlay {
                        if !unlocked {
                            Image(systemName: "lock.fill").font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                StarRow(stars: stars, size: 8)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(cellColor)
            )
            .overlay {
                if let branch {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(branch == .hard ? Color.red.opacity(0.5) : Color.green.opacity(0.5), lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
    }

    private var cellColor: Color {
        if !unlocked { return Color(.tertiarySystemFill) }
        if isBoss { return .orange.opacity(0.18) }
        return stars > 0 ? Color.accent.opacity(0.14) : Color(.secondarySystemGroupedBackground)
    }
}
