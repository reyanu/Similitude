import SwiftUI

/// AI Cartoon Portrait tab. Mirrors the Artistic Filters tile row exactly:
/// three square tiles, center tile active and Premium, sides Coming Soon.
/// Generation is gated on the on-device model being installed (Phase 3);
/// until then the state is reported honestly, never faked with Core Image.
struct AICartoonTab: View {
    @Bindable var model: StudioViewModel

    var body: some View {
        VStack(spacing: 10) {
            PortraitSourcePanel(
                image: model.sourceImage,
                statusMessage: model.statusMessage
            ) { image, source in
                model.setPhoto(image, source: source)
            }

            HStack(alignment: .top, spacing: 10) {
                StyleTile(
                    title: "Coming Soon",
                    previewAssetName: "preview_ai_coming_soon_left",
                    badge: .comingSoon,
                    isSelected: false,
                    isEnabled: false
                ) {}

                StyleTile(
                    title: "AI Cartoon Portrait",
                    previewAssetName: "preview_ai_cartoon",
                    badge: .premium,
                    isSelected: true,
                    isEnabled: true
                ) {}

                StyleTile(
                    title: "Coming Soon",
                    previewAssetName: "preview_ai_coming_soon_right",
                    badge: .comingSoon,
                    isSelected: false,
                    isEnabled: false
                ) {}
            }

            VStack(spacing: 6) {
                Button {
                    // Wired to AvatarGenerationCoordinator in Phase 3.
                } label: {
                    Text("Create AI Cartoon Portrait")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(true)

                Text("AI model is not installed. Download will be available in an upcoming update.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}
