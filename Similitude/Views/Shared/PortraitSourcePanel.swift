import SwiftUI
import PhotosUI

/// Compact photo-acquisition panel shared by Compare and Studio: shows the
/// current portrait (or a placeholder) with Scan and Library actions.
/// Designed to stay fully visible without scrolling on a standard iPhone.
struct PortraitSourcePanel: View {
    let image: UIImage?
    let statusMessage: String?
    let onPhoto: (UIImage, ImageSource) -> Void

    @State private var showCamera = false
    @State private var libraryItem: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: Brand.cardCornerRadius)
                    .fill(Brand.accentSoft)

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: Brand.cardCornerRadius))
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 44))
                            .foregroundStyle(Brand.accent)
                        Text("Scan a face or choose a photo")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 220)
            .accessibilityLabel(image == nil ? "No portrait selected" : "Selected portrait")

            if let statusMessage {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            HStack(spacing: 12) {
                Button {
                    showCamera = true
                } label: {
                    Label("Scan", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                PhotosPicker(selection: $libraryItem, matching: .images) {
                    Label("Library", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.large)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image, source in
                onPhoto(image, source)
            }
            .ignoresSafeArea()
        }
        .onChange(of: libraryItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    onPhoto(image, .photoLibrary)
                }
                libraryItem = nil
            }
        }
    }
}
