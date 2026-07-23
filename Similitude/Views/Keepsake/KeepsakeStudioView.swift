import SwiftUI
import PhotosUI

/// Keepsake flow: choose template → customize text (and portraits, for the
/// poster) → live preview → export. Reached with a portrait already in hand
/// from the Studio result sheets.
struct KeepsakeTemplatePickerView: View {
    let initialPortrait: UIImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Text("Choose a template")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(KeepsakeTemplate.all) { template in
                        NavigationLink {
                            KeepsakeEditorView(
                                model: KeepsakeViewModel(template: template, initialPortrait: initialPortrait)
                            )
                        } label: {
                            TemplateCard(template: template, enabled: true)
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(KeepsakeTemplate.comingSoonNames, id: \.self) { name in
                        ComingSoonTemplateCard(name: name)
                    }
                }
                .padding()
            }
            .brandBackground()
            .navigationTitle("Keepsake Studio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

private struct TemplateCard: View {
    let template: KeepsakeTemplate
    let enabled: Bool
    @State private var thumbnail: UIImage?

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let asset = UIImage(named: template.previewAsset) {
                    Image(uiImage: asset).resizable()
                } else if let thumbnail {
                    Image(uiImage: thumbnail).resizable()
                } else {
                    Rectangle().fill(Brand.accentSoft)
                        .overlay(ProgressView())
                }
            }
            .scaledToFill()
            .frame(width: 84, height: 105)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(template.displayName)
                    .font(.headline)
                Text(template.maxPortraits > 1
                     ? "\(template.minPortraits)–\(template.maxPortraits) family portraits"
                     : "One portrait")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            PlanBadge(kind: .premium)
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Brand.cardBackground, in: RoundedRectangle(cornerRadius: Brand.cardCornerRadius))
        .task {
            guard UIImage(named: template.previewAsset) == nil, thumbnail == nil else { return }
            // Live-rendered thumbnail with neutral silhouettes — honest
            // preview of the actual template, never a fake sample photo.
            let template = self.template
            thumbnail = await Task.detached(priority: .utility) {
                let silhouettes = Array(
                    repeating: KeepsakeViewModel.silhouettePortrait(),
                    count: template.minPortraits
                )
                return try? KeepsakeTemplateRenderer().render(
                    template: template,
                    portraits: silhouettes,
                    title: template.defaultTitle,
                    message: template.defaultMessage,
                    watermarked: false,
                    scale: 0.12
                )
            }.value
        }
    }
}

private struct ComingSoonTemplateCard: View {
    let name: String

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.tertiarySystemFill))
                .frame(width: 84, height: 105)
                .overlay(
                    Image(systemName: "hourglass")
                        .foregroundStyle(.secondary)
                )
            Text(name)
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
            PlanBadge(kind: .comingSoon)
        }
        .padding()
        .background(Brand.cardBackground.opacity(0.6), in: RoundedRectangle(cornerRadius: Brand.cardCornerRadius))
        .accessibilityLabel("\(name), coming soon")
    }
}
