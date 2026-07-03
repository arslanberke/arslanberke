import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: GameSettings
    @EnvironmentObject var progress: PlayerProgress

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: Binding(
                    get: { settings.appearance },
                    set: { settings.appearance = $0 })) {
                    ForEach(Appearance.allCases) { appearance in
                        Text(appearance.displayName).tag(appearance)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Feedback") {
                Toggle("Haptic feedback", isOn: $settings.hapticsEnabled)
                Toggle("Sound effects", isOn: $settings.soundEnabled)
                Toggle("Music", isOn: $settings.musicEnabled)
                    .onChange(of: settings.musicEnabled) { _, on in
                        on ? AudioManager.shared.startAmbient() : AudioManager.shared.stopAmbient()
                    }
            }

            Section("Accessibility") {
                Toggle("Reduce motion", isOn: $settings.reduceMotion)
                Toggle("High contrast pieces", isOn: $settings.highContrast)
                Toggle("Larger touch targets", isOn: $settings.largePieceHandles)
                Toggle("Color-blind patterns", isOn: $settings.colorBlindPatterns)
            }

            Section("Game Center") {
                Button("Leaderboards") { GameCenterService.shared.presentLeaderboards() }
            }

            Section("Developer") {
                Button("Unlock all levels") {
                    progress.highestUnlockedLevel = LevelCatalog.totalLevels
                }
                Button("Reset progress", role: .destructive) {
                    progress.highestUnlockedLevel = 1
                    progress.results = [:]
                    progress.totalStars = 0
                }
            }

            Section {
                LabeledContent("Version", value: "1.0.0")
                LabeledContent("Levels", value: "\(LevelCatalog.totalLevels)")
            } footer: {
                Text("Progress syncs automatically with iCloud.")
            }
        }
        .navigationTitle("Settings")
    }
}

struct AchievementsView: View {
    @EnvironmentObject var progress: PlayerProgress

    var body: some View {
        List(Achievement.all) { achievement in
            let unlocked = progress.unlockedAchievements.contains(achievement.id)
            HStack(spacing: 14) {
                Image(systemName: achievement.symbolName)
                    .font(.title3)
                    .foregroundStyle(unlocked ? Color.coin : .secondary)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(unlocked ? Color.coin.opacity(0.15) : Color(.tertiarySystemFill)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(achievement.name)
                        .font(.headline)
                        .foregroundStyle(unlocked ? .primary : .secondary)
                    Text(achievement.detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if unlocked {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                }
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("Achievements")
    }
}
