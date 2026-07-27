import SwiftUI

@main
struct ShapeSnapApp: App {
    @StateObject private var progress = PlayerProgress.shared
    @StateObject private var settings = GameSettings.shared
    @StateObject private var store = StoreService.shared

    init() {
        GameCenterService.shared.authenticate()
        CloudSyncService.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(progress)
                .environmentObject(settings)
                .environmentObject(store)
                .preferredColorScheme(settings.appearance.colorScheme)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var progress: PlayerProgress

    var body: some View {
        NavigationStack {
            HomeView()
        }
        .tint(.accent)
        .onAppear {
            DailyRewardService.shared.checkIn()
            AudioManager.shared.startAmbient()
        }
    }
}
