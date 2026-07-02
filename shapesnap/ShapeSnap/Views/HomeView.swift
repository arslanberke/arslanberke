import SwiftUI

struct HomeView: View {
    @EnvironmentObject var progress: PlayerProgress
    @State private var dailyReward: Int?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                continueCard
                modeGrid
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("ShapeSnap")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    NavigationLink { AchievementsView() } label: { Image(systemName: "rosette") }
                    NavigationLink { ShopView() } label: { Image(systemName: "paintpalette") }
                    NavigationLink { SettingsView() } label: { Image(systemName: "gearshape") }
                }
            }
        }
        .onAppear { dailyReward = DailyRewardService.shared.consumePendingReward() }
        .overlay(alignment: .top) {
            if let reward = dailyReward {
                DailyRewardBanner(amount: reward, streak: progress.loginStreak) {
                    withAnimation(.spring) { dailyReward = nil }
                }
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Welcome back")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 14) {
                    Label("\(progress.totalStars)", systemImage: "star.fill")
                        .foregroundStyle(Color.coin)
                    Label("\(progress.perfectMedals)", systemImage: "medal.fill")
                        .foregroundStyle(.purple)
                }
                .font(.headline.monospacedDigit())
            }
            Spacer()
            CoinBadge(amount: progress.coins)
        }
        .padding(.top, 4)
    }

    private var continueCard: some View {
        NavigationLink {
            GameView(session: GameSession.start(mode: .story, storyLevelID: min(progress.highestUnlockedLevel, LevelCatalog.totalLevels)))
        } label: {
            let levelID = min(progress.highestUnlockedLevel, LevelCatalog.totalLevels)
            let world = World.all.first { levelID < $0.firstLevelID + $0.levelCount } ?? World.all[0]
            VStack(alignment: .leading, spacing: 10) {
                Text("CONTINUE")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.8))
                Text("Level \(levelID)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("World \(world.id) · \(world.name)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                ProgressView(value: Double(levelID - world.firstLevelID), total: Double(world.levelCount))
                    .tint(.white)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(LinearGradient(colors: [.accent, .indigo],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: Color.accent.opacity(0.4), radius: 16, y: 8)
            )
        }
        .buttonStyle(.plain)
    }

    private var modeGrid: some View {
        VStack(spacing: 14) {
            NavigationLink { WorldMapView() } label: {
                ModeRow(mode: .story, badge: nil)
            }
            NavigationLink { GameView(session: GameSession.start(mode: .dailyChallenge)) } label: {
                ModeRow(mode: .dailyChallenge, badge: DailyChallengeService.completedToday ? "Done ✓" : "New")
            }
            NavigationLink { GameView(session: GameSession.start(mode: .timeAttack)) } label: {
                ModeRow(mode: .timeAttack, badge: progress.timeAttackBest > 0 ? "Best \(progress.timeAttackBest)" : nil)
            }
            NavigationLink { GameView(session: GameSession.start(mode: .endless)) } label: {
                ModeRow(mode: .endless, badge: progress.endlessBest > 0 ? "Round \(progress.endlessBest)" : nil)
            }
            NavigationLink { GameView(session: GameSession.start(mode: .hardcore, storyLevelID: min(progress.highestUnlockedLevel, LevelCatalog.totalLevels))) } label: {
                ModeRow(mode: .hardcore, badge: nil)
            }
            NavigationLink { GameView(session: GameSession.start(mode: .relax, storyLevelID: min(progress.highestUnlockedLevel, LevelCatalog.totalLevels))) } label: {
                ModeRow(mode: .relax, badge: nil)
            }
            Button { GameCenterService.shared.presentLeaderboards() } label: {
                HStack {
                    Image(systemName: "trophy.fill")
                        .font(.title3)
                        .foregroundStyle(.orange)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(.orange.opacity(0.15)))
                    Text("Leaderboards")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(16)
                .card(cornerRadius: 20)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct ModeRow: View {
    let mode: GameMode
    let badge: String?

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: mode.symbolName)
                .font(.title3)
                .foregroundStyle(Color.accent)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.accent.opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                Text(mode.displayName).font(.headline).foregroundStyle(.primary)
                Text(mode.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if let badge {
                Text(badge)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(Color.accent.opacity(0.12)))
                    .foregroundStyle(Color.accent)
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .card(cornerRadius: 20)
    }
}

private struct DailyRewardBanner: View {
    let amount: Int
    let streak: Int
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "gift.fill")
                .font(.title2)
                .foregroundStyle(Color.coin)
            VStack(alignment: .leading, spacing: 2) {
                Text("Daily Reward: +\(amount) coins").font(.headline)
                Text("Login streak: \(streak) day\(streak == 1 ? "" : "s")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Collect", action: dismiss)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
        }
        .padding(16)
        .card(cornerRadius: 20)
        .padding(.horizontal, 20)
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear { HapticsManager.shared.success() }
    }
}
