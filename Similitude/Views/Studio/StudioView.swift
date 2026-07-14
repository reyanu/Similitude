import SwiftUI

/// Similitude Studio: two tabs — Artistic Filters and AI Cartoon Portrait.
/// A single view model owns all state, so switching tabs repeatedly never
/// loses selection, freezes, or drops tap response.
struct StudioView: View {
    enum StudioTab: String, CaseIterable, Identifiable {
        case artisticFilters = "Artistic Filters"
        case aiCartoon = "AI Cartoon Portrait"
        var id: String { rawValue }
    }

    @State private var model = StudioViewModel()
    @State private var tab: StudioTab = .artisticFilters

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                Text("Choose Artistic Filters or Create premium AI cartoon")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Brand.accentSoft, in: RoundedRectangle(cornerRadius: 10))

                PrivacyBadge()
                    .frame(maxWidth: .infinity, alignment: .leading)

                Picker("Studio mode", selection: $tab) {
                    ForEach(StudioTab.allCases) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.segmented)

                switch tab {
                case .artisticFilters:
                    ArtisticFiltersTab(model: model)
                case .aiCartoon:
                    AICartoonTab(model: model)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal)
            .padding(.top, 4)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Similitude Studio")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $model.showResult) {
                StudioResultSheet(model: model)
            }
        }
    }
}

/// Single source of truth for Studio state, shared by both tabs so repeated
/// tab switching preserves the selected photo and results.
@Observable
@MainActor
final class StudioViewModel {
    var sourceImage: UIImage?
    var statusMessage: String?
    var selectedFilter: ArtisticFilterKind = .pencilSketch
    var resultImage: UIImage?
    var isProcessing = false
    var showResult = false

    /// Owned here (not by the tab view) so repeated tab switching never
    /// resets download or generation state.
    let avatar = AvatarGenerationCoordinator()

    private let detector = FaceDetectionService()

    func setPhoto(_ image: UIImage, source: ImageSource) {
        Task { @MainActor in
            statusMessage = nil
            do {
                let face = try await Task.detached(priority: .userInitiated) { [detector] in
                    try detector.detectFace(in: image, source: source)
                }.value
                sourceImage = face.normalizedImage
                statusMessage = "Face detected ✓ — choose a style below"
            } catch {
                sourceImage = nil
                statusMessage = error.localizedDescription
            }
        }
    }

    func applySelectedFilter() {
        guard let sourceImage, !isProcessing else { return }
        isProcessing = true
        let kind = selectedFilter
        Task { @MainActor in
            defer { isProcessing = false }
            do {
                let filter: ArtisticFilter
                switch kind {
                case .pencilSketch: filter = PencilSketchFilter()
                case .posterArt: filter = PosterArtFilter()
                case .softCartoon: filter = SoftCartoonFilter()
                }
                let output = try await Task.detached(priority: .userInitiated) {
                    try filter.apply(to: sourceImage)
                }.value
                resultImage = output
                showResult = true
            } catch {
                statusMessage = "The style could not be applied. Try another photo."
            }
        }
    }
}

private struct StudioResultSheet: View {
    let model: StudioViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                if let result = model.resultImage {
                    Image(uiImage: result)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: Brand.cardCornerRadius))
                        .padding()
                }
                Spacer()
            }
            .navigationTitle(model.selectedFilter.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    StudioView()
}
