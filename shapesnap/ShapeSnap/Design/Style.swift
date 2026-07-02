import SwiftUI

extension Color {
    static let accent = Color(red: 0.28, green: 0.48, blue: 1.0)
    static let coin = Color(red: 1.0, green: 0.72, blue: 0.2)
}

/// Soft, rounded, Apple-like card container.
struct CardBackground: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    var cornerRadius: CGFloat = 24

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(scheme == .dark ? Color(.secondarySystemBackground) : .white)
                    .shadow(color: .black.opacity(scheme == .dark ? 0.35 : 0.08),
                            radius: 14, x: 0, y: 6)
            )
    }
}

extension View {
    func card(cornerRadius: CGFloat = 24) -> some View {
        modifier(CardBackground(cornerRadius: cornerRadius))
    }
}

/// Primary pill button with a springy press animation.
struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = .accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(color.gradient))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct CoinBadge: View {
    let amount: Int
    var body: some View {
        Label("\(amount)", systemImage: "circle.hexagongrid.circle.fill")
            .font(.subheadline.weight(.semibold).monospacedDigit())
            .foregroundStyle(Color.coin)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(.thinMaterial))
            .accessibilityLabel("\(amount) coins")
    }
}

struct StarRow: View {
    let stars: Int
    var size: CGFloat = 14
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < stars ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(index < stars ? Color.coin : Color.secondary.opacity(0.4))
            }
        }
        .accessibilityLabel("\(stars) of 3 stars")
    }
}
