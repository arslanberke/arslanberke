import UIKit
import CoreHaptics

/// Centralized haptic feedback with a custom "snap" pattern via Core Haptics.
final class HapticsManager {
    static let shared = HapticsManager()

    private var engine: CHHapticEngine?
    private let impactSoft = UIImpactFeedbackGenerator(style: .soft)
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let notification = UINotificationFeedbackGenerator()

    private var enabled: Bool { GameSettings.shared.hapticsEnabled }

    private init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        engine = try? CHHapticEngine()
        engine?.resetHandler = { [weak self] in try? self?.engine?.start() }
        try? engine?.start()
    }

    func soft() { guard enabled else { return }; impactSoft.impactOccurred() }
    func light() { guard enabled else { return }; impactLight.impactOccurred() }
    func medium() { guard enabled else { return }; impactMedium.impactOccurred() }
    func success() { guard enabled else { return }; notification.notificationOccurred(.success) }
    func warning() { guard enabled else { return }; notification.notificationOccurred(.warning) }
    func error() { guard enabled else { return }; notification.notificationOccurred(.error) }

    /// A crisp two-stage click used when a piece snaps into its socket.
    func snap() {
        guard enabled else { return }
        guard let engine else { impactMedium.impactOccurred(); return }
        let sharp = CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9),
        ], relativeTime: 0)
        let soft = CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3),
        ], relativeTime: 0.07)
        if let pattern = try? CHHapticPattern(events: [sharp, soft], parameters: []),
           let player = try? engine.makePlayer(with: pattern) {
            try? player.start(atTime: 0)
        } else {
            impactMedium.impactOccurred()
        }
    }
}
