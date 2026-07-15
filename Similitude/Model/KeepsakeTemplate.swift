import UIKit

/// How a portrait is masked into its frame.
enum PortraitMask {
    case circle(featherFraction: CGFloat)
    case roundedRect(cornerFraction: CGFloat, featherFraction: CGFloat)
}

/// Text styling for a template's title and message.
struct KeepsakeTextStyle {
    let titleColor: UIColor
    let messageColor: UIColor
    let titleFontSize: CGFloat
    let messageFontSize: CGFloat
    let usesSerif: Bool
}

/// A layered keepsake template. Backgrounds and foregrounds come from the
/// asset catalog when present (real artwork), otherwise from the
/// programmatic fallback painters — no sample person exists in either.
struct KeepsakeTemplate: Identifiable {
    let id: String
    let displayName: String
    let backgroundAsset: String
    let foregroundAsset: String?
    let previewAsset: String
    /// Portrait frames per supported portrait count, listed back-to-front.
    let portraitLayouts: [Int: [CGRect]]
    let portraitMask: PortraitMask
    let defaultTitle: String
    let defaultMessage: String
    let titleFrame: CGRect
    let messageFrame: CGRect
    let textStyle: KeepsakeTextStyle

    /// Spec canvas: 1600 × 2000 portrait.
    static let canvasSize = CGSize(width: 1600, height: 2000)

    var minPortraits: Int { portraitLayouts.keys.min() ?? 1 }
    var maxPortraits: Int { portraitLayouts.keys.max() ?? 1 }

    func frames(for portraitCount: Int) -> [CGRect]? {
        portraitLayouts[portraitCount]
    }
}

// MARK: - V1 registry

extension KeepsakeTemplate {

    static let birthday = KeepsakeTemplate(
        id: "birthday",
        displayName: "Birthday Card",
        backgroundAsset: "birthday_background",
        foregroundAsset: "birthday_foreground",
        previewAsset: "birthday_preview",
        portraitLayouts: [1: [CGRect(x: 400, y: 560, width: 800, height: 800)]],
        portraitMask: .circle(featherFraction: 0.05),
        defaultTitle: "Happy Birthday!",
        defaultMessage: "You make every day brighter!",
        titleFrame: CGRect(x: 160, y: 190, width: 1280, height: 240),
        messageFrame: CGRect(x: 200, y: 1480, width: 1200, height: 220),
        textStyle: KeepsakeTextStyle(
            titleColor: UIColor(red: 0.85, green: 0.35, blue: 0.55, alpha: 1),
            messageColor: UIColor(red: 0.45, green: 0.35, blue: 0.55, alpha: 1),
            titleFontSize: 130,
            messageFontSize: 72,
            usesSerif: true
        )
    )

    static let graduation = KeepsakeTemplate(
        id: "graduation",
        displayName: "Graduation Card",
        backgroundAsset: "graduation_background",
        foregroundAsset: "graduation_foreground",
        previewAsset: "graduation_preview",
        portraitLayouts: [1: [CGRect(x: 440, y: 600, width: 720, height: 720)]],
        portraitMask: .roundedRect(cornerFraction: 0.12, featherFraction: 0.035),
        defaultTitle: "Congratulations\nGRADUATE!",
        defaultMessage: "THE FUTURE IS YOURS\nDream Big • Work Hard • Stay Kind",
        titleFrame: CGRect(x: 160, y: 190, width: 1280, height: 340),
        messageFrame: CGRect(x: 200, y: 1460, width: 1200, height: 280),
        textStyle: KeepsakeTextStyle(
            titleColor: UIColor(red: 0.10, green: 0.15, blue: 0.35, alpha: 1),
            messageColor: UIColor(red: 0.62, green: 0.50, blue: 0.16, alpha: 1),
            titleFontSize: 110,
            messageFontSize: 60,
            usesSerif: true
        )
    )

    static let familyPoster = KeepsakeTemplate(
        id: "familyPoster",
        displayName: "Family Poster",
        backgroundAsset: "family_background",
        foregroundAsset: "family_foreground",
        previewAsset: "family_preview",
        // Child centered and slightly forward, adults behind/beside,
        // additional member balanced above — back-to-front draw order.
        portraitLayouts: [
            2: [
                CGRect(x: 220, y: 640, width: 560, height: 560),
                CGRect(x: 700, y: 800, width: 660, height: 660),
            ],
            3: [
                CGRect(x: 170, y: 620, width: 500, height: 500),
                CGRect(x: 930, y: 620, width: 500, height: 500),
                CGRect(x: 500, y: 860, width: 600, height: 600),
            ],
            4: [
                CGRect(x: 620, y: 360, width: 360, height: 360),
                CGRect(x: 170, y: 640, width: 480, height: 480),
                CGRect(x: 950, y: 640, width: 480, height: 480),
                CGRect(x: 510, y: 880, width: 580, height: 580),
            ],
        ],
        portraitMask: .circle(featherFraction: 0.10),
        defaultTitle: "Family",
        defaultMessage: "Where love begins & never ends\nTOGETHER WE HAVE IT ALL\nLOVE • LAUGHTER • MEMORIES",
        titleFrame: CGRect(x: 300, y: 120, width: 1000, height: 200),
        messageFrame: CGRect(x: 200, y: 1560, width: 1200, height: 300),
        textStyle: KeepsakeTextStyle(
            titleColor: UIColor(red: 0.35, green: 0.42, blue: 0.32, alpha: 1),
            messageColor: UIColor(red: 0.42, green: 0.40, blue: 0.36, alpha: 1),
            titleFontSize: 150,
            messageFontSize: 56,
            usesSerif: true
        )
    )

    /// Fully implemented V1 templates.
    static let all: [KeepsakeTemplate] = [birthday, graduation, familyPoster]

    /// Honest placeholders shown disabled in the picker.
    static let comingSoonNames = ["New Baby", "Holiday Card", "Anniversary"]
}
