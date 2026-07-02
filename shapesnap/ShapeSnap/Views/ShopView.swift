import SwiftUI
import StoreKit

struct ShopView: View {
    @EnvironmentObject var progress: PlayerProgress
    @EnvironmentObject var store: StoreService

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                CoinBadge(amount: progress.coins)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                section("Themes") {
                    ForEach(Theme.all) { theme in
                        ThemeRow(theme: theme,
                                 owned: progress.unlockedThemes.contains(theme.id),
                                 selected: progress.selectedTheme == theme.id) {
                            handleThemeTap(theme)
                        }
                    }
                }

                section("Purchases") {
                    if progress.removeAdsPurchased {
                        Label("Ads removed — thank you!", systemImage: "checkmark.seal.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.green)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .card(cornerRadius: 18)
                    }
                    ForEach(store.products, id: \.id) { product in
                        ProductRow(product: product,
                                   owned: store.purchasedIDs.contains(product.id)) {
                            Task { await store.purchase(product) }
                        }
                    }
                    Button("Restore Purchases") { Task { await store.restore() } }
                        .font(.subheadline.weight(.semibold))

                    Button {
                        AdsService.shared.showRewardedAd { success in
                            if success {
                                progress.coins += 50
                                AudioManager.shared.play(.coin)
                                HapticsManager.shared.success()
                            }
                        }
                    } label: {
                        Label("Watch ad · +50 coins", systemImage: "play.rectangle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .card(cornerRadius: 18)
                    }
                    .buttonStyle(.plain)
                    .opacity(AdsService.shared.adsRemoved ? 0 : 1)
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Shop")
    }

    private func handleThemeTap(_ theme: Theme) {
        if progress.unlockedThemes.contains(theme.id) {
            progress.selectedTheme = theme.id
            HapticsManager.shared.light()
        } else if progress.coins >= theme.price {
            progress.coins -= theme.price
            progress.unlockedThemes.insert(theme.id)
            progress.selectedTheme = theme.id
            AudioManager.shared.play(.coin)
            HapticsManager.shared.success()
        } else {
            HapticsManager.shared.warning()
        }
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title3.weight(.bold))
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ThemeRow: View {
    let theme: Theme
    let owned: Bool
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                HStack(spacing: 4) {
                    ForEach(Array(theme.pieceColors.enumerated()), id: \.offset) { _, color in
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(color.gradient)
                            .frame(width: 20, height: 32)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.name).font(.headline).foregroundStyle(.primary)
                    if owned {
                        Text(selected ? "Selected" : "Owned")
                            .font(.caption).foregroundStyle(selected ? Color.accent : .secondary)
                    } else {
                        Label("\(theme.price)", systemImage: "circle.hexagongrid.circle.fill")
                            .font(.caption.weight(.semibold)).foregroundStyle(Color.coin)
                    }
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accent)
                }
            }
            .padding(14)
            .card(cornerRadius: 18)
        }
        .buttonStyle(.plain)
    }
}

private struct ProductRow: View {
    let product: Product
    let owned: Bool
    let buy: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(product.displayName).font(.headline)
                Text(product.description).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if owned {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                Button(product.displayPrice, action: buy)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
            }
        }
        .padding(16)
        .card(cornerRadius: 18)
    }
}
