import SwiftUI

/// Square style-preview tile used identically by Artistic Filters and
/// AI Cartoon Portrait so both rows share width, height, corner radius,
/// aspect ratio, spacing, and caption placement.
struct StyleTile: View {
    let title: String
    let previewAssetName: String?
    let badge: PlanBadge.Kind
    let isSelected: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    preview
                        .aspectRatio(1, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: Brand.tileCornerRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: Brand.tileCornerRadius)
                                .strokeBorder(
                                    isSelected ? Brand.accent : .clear,
                                    lineWidth: 2.5
                                )
                        )

                    PlanBadge(kind: badge)
                        .padding(5)
                }

                Text(title)
                    .font(.caption.weight(.medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 30, alignment: .top)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.55)
        .accessibilityLabel("\(title)\(isSelected ? ", selected" : "")")
    }

    @ViewBuilder
    private var preview: some View {
        if let previewAssetName, UIImage(named: previewAssetName) != nil {
            Image(previewAssetName)
                .resizable()
                .scaledToFill()
        } else {
            // Honest placeholder — never silently substitute a generic icon.
            ZStack {
                Rectangle().fill(Brand.accentSoft)
                Text("Preview coming soon")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(4)
            }
        }
    }
}
