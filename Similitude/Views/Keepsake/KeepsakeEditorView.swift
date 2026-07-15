import SwiftUI
import PhotosUI

@Observable
@MainActor
final class KeepsakeViewModel {
    let template: KeepsakeTemplate
    var portraits: [UIImage]
    var title: String
    var message: String

    private(set) var preview: UIImage?
    private(set) var isRendering = false
    var exportMessage: String?
    var isExporting = false
    var showPaywall = false
    var portraitStatus: String?

    let entitlements = EntitlementsService.shared
    private let renderer = KeepsakeTemplateRenderer()
    private let exporter = ExportService()
    private let detector = FaceDetectionService()
    private var renderTask: Task<Void, Never>?

    init(template: KeepsakeTemplate, initialPortrait: UIImage) {
        self.template = template
        self.portraits = [initialPortrait]
        self.title = template.defaultTitle
        self.message = template.defaultMessage
    }

    var needsMorePortraits: Bool {
        portraits.count < template.minPortraits
    }

    var canAddPortrait: Bool {
        portraits.count < template.maxPortraits
    }

    /// Poster portraits go through the shared face pipeline so they are
    /// upright, un-mirrored, and framed on the face.
    func addPortrait(_ image: UIImage, source: ImageSource) {
        guard canAddPortrait else { return }
        Task { @MainActor in
            do {
                let face = try await Task.detached(priority: .userInitiated) { [detector] in
                    try detector.detectFace(in: image, source: source)
                }.value
                portraits.append(face.normalizedImage)
                portraitStatus = nil
                schedulePreviewRender()
            } catch {
                portraitStatus = error.localizedDescription
            }
        }
    }

    func removePortrait(at index: Int) {
        guard portraits.indices.contains(index), portraits.count > 1 else { return }
        portraits.remove(at: index)
        schedulePreviewRender()
    }

    /// Debounced background preview render at reduced resolution.
    func schedulePreviewRender() {
        renderTask?.cancel()
        let template = template
        let portraits = renderablePortraits()
        let title = title
        let message = message
        let watermarkPreview = !entitlements.isPremium

        isRendering = true
        renderTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            let image = await Task.detached(priority: .userInitiated) {
                try? KeepsakeTemplateRenderer().render(
                    template: template,
                    portraits: portraits,
                    title: title,
                    message: message,
                    watermarked: watermarkPreview,
                    scale: 0.35
                )
            }.value
            guard !Task.isCancelled else { return }
            preview = image
            isRendering = false
        }
    }

    /// Keepsakes are a Premium feature; export gates on the plan.
    func export() {
        exportMessage = nil
        guard entitlements.isPremium else {
            showPaywall = true
            return
        }
        guard !needsMorePortraits else {
            exportMessage = "Add at least \(template.minPortraits) portraits first."
            return
        }
        isExporting = true
        let template = template
        let portraits = portraits
        let title = title
        let message = message
        Task { @MainActor in
            defer { isExporting = false }
            do {
                let full = try await Task.detached(priority: .userInitiated) {
                    try KeepsakeTemplateRenderer().render(
                        template: template,
                        portraits: portraits,
                        title: title,
                        message: message,
                        watermarked: false,
                        scale: 1.0
                    )
                }.value
                try await exporter.saveToPhotoLibrary(full)
                exportMessage = "Saved to Photos."
            } catch {
                exportMessage = error.localizedDescription
            }
        }
    }

    /// Pads with neutral silhouettes so the preview always renders, even
    /// while the poster still needs more portraits.
    private func renderablePortraits() -> [UIImage] {
        var result = portraits
        while result.count < template.minPortraits {
            result.append(Self.silhouettePortrait())
        }
        return result
    }

    /// Neutral head-and-shoulders placeholder — clearly not a real person.
    nonisolated static func silhouettePortrait(size: CGSize = CGSize(width: 400, height: 400)) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let cg = ctx.cgContext
            UIColor(white: 0.88, alpha: 1).setFill()
            cg.fill(CGRect(origin: .zero, size: size))
            UIColor(white: 0.70, alpha: 1).setFill()
            // Head
            cg.fillEllipse(in: CGRect(x: size.width * 0.325, y: size.height * 0.18,
                                      width: size.width * 0.35, height: size.height * 0.38))
            // Shoulders
            cg.fillEllipse(in: CGRect(x: size.width * 0.15, y: size.height * 0.62,
                                      width: size.width * 0.7, height: size.height * 0.55))
        }
    }
}

struct KeepsakeEditorView: View {
    @State var model: KeepsakeViewModel
    @State private var libraryItem: PhotosPickerItem?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: Brand.cardCornerRadius)
                        .fill(Brand.accentSoft)
                        .aspectRatio(0.8, contentMode: .fit)

                    if let preview = model.preview {
                        Image(uiImage: preview)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: Brand.cardCornerRadius))
                    }
                    if model.isRendering {
                        ProgressView()
                    }
                }

                if model.template.maxPortraits > 1 {
                    portraitRow
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Title")
                        .font(.subheadline.weight(.semibold))
                    TextField("Title", text: $model.title, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                    Text("Message")
                        .font(.subheadline.weight(.semibold))
                    TextField("Message", text: $model.message, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                }

                if let status = model.portraitStatus {
                    Text(status)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                if let message = model.exportMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button {
                    model.export()
                } label: {
                    if model.isExporting {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Label("Export Keepsake", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(model.isExporting || model.needsMorePortraits)

                if model.needsMorePortraits {
                    Text("Add at least \(model.template.minPortraits) family portraits for this template.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if !model.entitlements.isPremium {
                    Text("Keepsake export is a Premium feature.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(model.template.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task { model.schedulePreviewRender() }
        .onChange(of: model.title) { model.schedulePreviewRender() }
        .onChange(of: model.message) { model.schedulePreviewRender() }
        .sheet(isPresented: $model.showPaywall) {
            PremiumUpgradeView()
        }
        .onChange(of: libraryItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    model.addPortrait(image, source: .photoLibrary)
                }
                libraryItem = nil
            }
        }
    }

    private var portraitRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Family portraits (\(model.portraits.count)/\(model.template.maxPortraits))")
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 10) {
                ForEach(Array(model.portraits.enumerated()), id: \.offset) { index, portrait in
                    Image(uiImage: portrait)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(Circle())
                        .overlay(alignment: .topTrailing) {
                            if model.portraits.count > 1 {
                                Button {
                                    model.removePortrait(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.white, .gray)
                                }
                                .accessibilityLabel("Remove portrait \(index + 1)")
                            }
                        }
                }
                if model.canAddPortrait {
                    PhotosPicker(selection: $libraryItem, matching: .images) {
                        Circle()
                            .fill(Brand.accentSoft)
                            .frame(width: 64, height: 64)
                            .overlay(
                                Image(systemName: "plus")
                                    .foregroundStyle(Brand.accent)
                            )
                    }
                    .accessibilityLabel("Add family portrait")
                }
                Spacer()
            }
        }
    }
}
