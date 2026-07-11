import SwiftUI

/// Central brand constants: colors, copy, and shared styling.
enum Brand {
    // MARK: Colors

    static let accent = Color(red: 0.45, green: 0.30, blue: 0.85)
    static let accentSoft = Color(red: 0.45, green: 0.30, blue: 0.85).opacity(0.12)
    static let cardBackground = Color(.secondarySystemGroupedBackground)
    static let premiumGold = Color(red: 0.85, green: 0.65, blue: 0.15)

    // MARK: Copy

    static let privacyMessage = "Private. On-device. Your family photos never leave your phone."

    static let entertainmentDisclaimer = """
    Resemblance results are for entertainment and family keepsake purposes only. \
    They are not proof of biological relationship, identity, or genetics.
    """

    // MARK: Shared styling

    static let cardCornerRadius: CGFloat = 16
    static let tileCornerRadius: CGFloat = 14
}

/// Reusable privacy banner shown throughout the app.
struct PrivacyBadge: View {
    var body: some View {
        Label(Brand.privacyMessage, systemImage: "lock.shield.fill")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .accessibilityLabel("Privacy: \(Brand.privacyMessage)")
    }
}

/// Small capsule badge for FREE / PREMIUM labeling on tiles.
struct PlanBadge: View {
    enum Kind {
        case free, premium, comingSoon
    }

    let kind: Kind

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(background, in: Capsule())
            .foregroundStyle(.white)
    }

    private var text: String {
        switch kind {
        case .free: return "FREE"
        case .premium: return "PREMIUM"
        case .comingSoon: return "COMING SOON"
        }
    }

    private var background: Color {
        switch kind {
        case .free: return .green
        case .premium: return Brand.premiumGold
        case .comingSoon: return .gray
        }
    }
}
