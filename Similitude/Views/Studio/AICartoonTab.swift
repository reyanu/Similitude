import SwiftUI

/// AI Cartoon Portrait tab. Mirrors the Artistic Filters tile row exactly:
/// three square tiles, center tile active and Premium, sides Coming Soon.
/// Generation uses the installed Photo2Cartoon Core ML model only — there
/// is no Core Image fallback masquerading as AI.
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

            actionArea
        }
        .sheet(isPresented: Binding(
            get: { model.avatar.lastResult != nil },
            set: { if !$0 { model.avatar.clearResult() } }
        )) {
            if let result = model.avatar.lastResult {
                AvatarResultSheet(image: result, model: model)
            }
        }
        .sheet(isPresented: $model.showPaywall) {
            PremiumUpgradeView()
        }
    }

    @ViewBuilder
    private var actionArea: some View {
        switch model.avatar.state {
        case .notInstalled:
            VStack(spacing: 6) {
                Button {
                    model.avatar.downloadAndInstall()
                } label: {
                    Label("Download AI Model", systemImage: "arrow.down.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Text("AI model is not installed. Download it once to create portraits on your device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

        case .downloading(let progress):
            VStack(spacing: 6) {
                ProgressView(value: progress)
                Text(progress > 0
                     ? "Downloading model… \(Int(progress * 100))%"
                     : "Preparing download…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)

        case .installed:
            Button {
                guard model.entitlements.isPremium else {
                    model.showPaywall = true
                    return
                }
                if let image = model.sourceImage {
                    model.avatar.generate(from: image)
                }
            } label: {
                Text("Create AI Cartoon Portrait")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(model.sourceImage == nil)

        case .generating:
            VStack(spacing: 6) {
                ProgressView()
                Text("Creating your portrait on this device…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)

        case .failed(let message):
            VStack(spacing: 6) {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                HStack(spacing: 12) {
                    Button("Try Again") {
                        model.avatar.acknowledgeFailure()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}

private struct AvatarResultSheet: View {
    let image: UIImage
    @Bindable var model: StudioViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: Brand.cardCornerRadius))
                    .padding(.horizontal)

                if let message = model.exportMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    model.export(image)
                } label: {
                    if model.isExporting {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Label("Save to Photos", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(model.isExporting)
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("AI Cartoon Portrait")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
