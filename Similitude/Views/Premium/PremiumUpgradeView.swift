import SwiftUI

/// The upgrade screen, shown when the free export limit is reached or a
/// premium feature is tapped.
struct PremiumUpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var entitlements = EntitlementsService.shared
    @State private var errorMessage: String?

    private let benefits: [(icon: String, text: String)] = [
        ("wand.and.stars", "AI Portrait Studio — genuine on-device AI cartoon portraits"),
        ("person.3.fill", "Unlimited family members"),
        ("clock.arrow.circlepath", "Unlimited resemblance history & full Family Timeline"),
        ("square.and.arrow.up", "Unlimited exports in high resolution"),
        ("checkmark.seal.fill", "No watermark"),
        ("gift.fill", "Birthday Card, Graduation Card & Family Poster keepsakes"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Brand.premiumGold)
                        .padding(.top, 12)

                    Text("Similitude Premium")
                        .font(.title2.bold())

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(benefits, id: \.text) { benefit in
                            Label {
                                Text(benefit.text)
                                    .font(.subheadline)
                            } icon: {
                                Image(systemName: benefit.icon)
                                    .foregroundStyle(Brand.accent)
                                    .frame(width: 26)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Brand.cardBackground, in: RoundedRectangle(cornerRadius: Brand.cardCornerRadius))

                    PrivacyBadge()

                    if entitlements.isPremium {
                        Label("You're Premium — thank you!", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                            .font(.headline)
                    } else {
                        VStack(spacing: 10) {
                            Button {
                                Task {
                                    do {
                                        try await entitlements.purchase()
                                    } catch {
                                        errorMessage = error.localizedDescription
                                    }
                                }
                            } label: {
                                Group {
                                    if entitlements.purchaseInProgress {
                                        ProgressView()
                                    } else if let product = entitlements.product {
                                        Text("Upgrade — \(product.displayPrice)")
                                    } else {
                                        Text("Upgrade to Premium")
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(entitlements.purchaseInProgress)

                            Button("Restore Purchases") {
                                Task { await entitlements.restorePurchases() }
                            }
                            .font(.subheadline)
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    Text("Auto-renewable subscription. Cancel anytime in Settings.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                if entitlements.product == nil {
                    await entitlements.loadProduct()
                }
            }
        }
    }
}

#Preview {
    PremiumUpgradeView()
}
