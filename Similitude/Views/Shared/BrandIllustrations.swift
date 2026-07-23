import SwiftUI

/// Code-drawn brand illustrations for the Home experience cards — silhouette
/// style in light blue and purple, no photographic sample people.

/// A person silhouette: head circle over a rounded-shoulder body.
private struct PersonSilhouette: View {
    var color: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: w * 0.44, height: w * 0.44)
                    .position(x: w / 2, y: h * 0.26)
                Ellipse()
                    .fill(color)
                    .frame(width: w * 0.95, height: h * 0.62)
                    .position(x: w / 2, y: h * 0.78)
            }
        }
    }
}

/// Family: child at the center flanked by a parent on each side.
struct FamilyIllustration: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                PersonSilhouette(color: Brand.lightBlue.opacity(0.75))
                    .frame(width: w * 0.34, height: h * 0.8)
                    .position(x: w * 0.24, y: h * 0.5)
                PersonSilhouette(color: Brand.accent.opacity(0.75))
                    .frame(width: w * 0.34, height: h * 0.8)
                    .position(x: w * 0.76, y: h * 0.5)
                PersonSilhouette(color: .white.opacity(0.95))
                    .frame(width: w * 0.28, height: h * 0.62)
                    .position(x: w * 0.5, y: h * 0.62)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Studio: a portrait frame with a brush stroke and sparkles.
struct StudioIllustration: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                RoundedRectangle(cornerRadius: w * 0.08)
                    .strokeBorder(Brand.lightBlue.opacity(0.9), lineWidth: w * 0.035)
                    .frame(width: w * 0.52, height: h * 0.82)
                    .position(x: w * 0.42, y: h * 0.5)
                PersonSilhouette(color: .white.opacity(0.9))
                    .frame(width: w * 0.3, height: h * 0.52)
                    .position(x: w * 0.42, y: h * 0.56)
                Image(systemName: "paintbrush.pointed.fill")
                    .font(.system(size: w * 0.2))
                    .foregroundStyle(Brand.accent)
                    .rotationEffect(.degrees(-20))
                    .position(x: w * 0.78, y: h * 0.32)
                Image(systemName: "sparkles")
                    .font(.system(size: w * 0.13))
                    .foregroundStyle(Brand.premiumGold)
                    .position(x: w * 0.8, y: h * 0.72)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Timeline: portraits growing along a line.
struct TimelineIllustration: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Capsule()
                    .fill(Brand.lightBlue.opacity(0.5))
                    .frame(width: w * 0.86, height: h * 0.05)
                    .position(x: w * 0.5, y: h * 0.78)
                ForEach(0..<3, id: \.self) { index in
                    let scale = 0.5 + CGFloat(index) * 0.25
                    Circle()
                        .fill(index == 2 ? Brand.accent : Color.white.opacity(0.85))
                        .frame(width: w * 0.2 * scale + w * 0.08, height: w * 0.2 * scale + w * 0.08)
                        .position(x: w * (0.2 + CGFloat(index) * 0.3), y: h * 0.45)
                    Circle()
                        .fill(Brand.lightBlue)
                        .frame(width: w * 0.045, height: w * 0.045)
                        .position(x: w * (0.2 + CGFloat(index) * 0.3), y: h * 0.78)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// Keepsake: a greeting card with a heart seal.
struct KeepsakeIllustration: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                RoundedRectangle(cornerRadius: w * 0.06)
                    .fill(Color.white.opacity(0.14))
                    .frame(width: w * 0.5, height: h * 0.85)
                    .rotationEffect(.degrees(-8))
                    .position(x: w * 0.38, y: h * 0.52)
                RoundedRectangle(cornerRadius: w * 0.06)
                    .fill(Brand.lightBlue.opacity(0.35))
                    .frame(width: w * 0.5, height: h * 0.85)
                    .rotationEffect(.degrees(4))
                    .position(x: w * 0.55, y: h * 0.48)
                PersonSilhouette(color: .white.opacity(0.9))
                    .frame(width: w * 0.22, height: h * 0.4)
                    .position(x: w * 0.55, y: h * 0.44)
                Image(systemName: "heart.fill")
                    .font(.system(size: w * 0.16))
                    .foregroundStyle(Brand.accent)
                    .position(x: w * 0.8, y: h * 0.75)
            }
        }
        .accessibilityHidden(true)
    }
}
