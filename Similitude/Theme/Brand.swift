import SwiftUI

/// Central brand constants: colors, copy, and shared styling.
/// Palette: dark blue backgrounds, light blue + purple accents, white text.
enum Brand {
    // MARK: Colors

    /// Deep navy — darkest background tone.
    static let deepNavy = Color(red: 0.06, green: 0.08, blue: 0.20)
    /// Mid navy — gradient partner and elevated surfaces.
    static let navy = Color(red: 0.10, green: 0.14, blue: 0.30)
    /// Light blue — secondary accent for icons and highlights.
    static let lightBlue = Color(red: 0.45, green: 0.72, blue: 0.96)
    /// Purple — primary accent for buttons and interactive elements.
    static let accent = Color(red: 0.58, green: 0.45, blue: 0.96)
    static let accentSoft = Color(red: 0.58, green: 0.45, blue: 0.96).opacity(0.22)
    /// Card surface: lifted navy with a purple cast.
    static let cardBackground = Color(red: 0.15, green: 0.18, blue: 0.36)
    static let premiumGold = Color(red: 0.92, green: 0.75, blue: 0.30)

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

/// Full-screen brand gradient used as the background of every page.
struct BrandBackground: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: Brand.deepNavy, location: 0),
                .init(color: Brand.navy, location: 0.55),
                .init(color: Color(red: 0.18, green: 0.13, blue: 0.36), location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

extension View {
    /// Applies the brand gradient behind any screen's content.
    func brandBackground() -> some View {
        background(BrandBackground())
    }

    /// Brand background for List/Form screens (hides the system backdrop).
    func brandListBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(BrandBackground())
    }
}

/// Reusable privacy banner shown throughout the app.
struct PrivacyBadge: View {
    var body: some View {
        Label(Brand.privacyMessage, systemImage: "lock.shield.fill")
            .font(.footnote)
            .foregroundStyle(Brand.lightBlue)
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
            .foregroundStyle(kind == .comingSoon ? Color.white.opacity(0.85) : .white)
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
        case .free: return Brand.lightBlue.opacity(0.85)
        case .premium: return Brand.premiumGold
        case .comingSoon: return Color.white.opacity(0.22)
        }
    }
}
