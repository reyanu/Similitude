import SwiftUI

struct ArtisticFiltersTab: View {
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
                ForEach(ArtisticFilterKind.allCases) { kind in
                    StyleTile(
                        title: kind.displayName,
                        previewAssetName: kind.previewAssetName,
                        badge: .free,
                        isSelected: model.selectedFilter == kind,
                        isEnabled: true
                    ) {
                        model.selectedFilter = kind
                    }
                }
            }

            Button {
                model.applySelectedFilter()
            } label: {
                if model.isProcessing {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Apply \(model.selectedFilter.displayName)")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(model.sourceImage == nil || model.isProcessing)
        }
    }
}
