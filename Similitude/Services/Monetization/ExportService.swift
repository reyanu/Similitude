import UIKit
import Photos

enum ExportError: LocalizedError {
    case limitReached
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .limitReached:
            return "You've used all free exports for this week."
        case .saveFailed(let reason):
            return "Export could not be completed: \(reason)"
        }
    }
}

/// Prepares and saves exports according to the user's plan:
/// free → 720p-class resolution + Similitude watermark; premium → full
/// resolution, no watermark.
struct ExportService {

    /// Free exports are capped at a 1280-pixel longest edge (720p class).
    static let freeMaxDimension: CGFloat = 1280

    private let watermark = WatermarkService()

    /// Applies plan rules to the image without saving — also used to show
    /// non-premium users an honest preview of what will be exported.
    func prepareForExport(_ image: UIImage, isPremium: Bool) -> UIImage {
        guard !isPremium else { return image }
        let downscaled = Self.downscaled(image, maxDimension: Self.freeMaxDimension)
        return watermark.applyWatermark(to: downscaled)
    }

    /// Saves to the photo library (add-only access; iOS prompts on first use).
    func saveToPhotoLibrary(_ image: UIImage) async throws {
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
        } catch {
            throw ExportError.saveFailed(error.localizedDescription)
        }
    }

    static func downscaled(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let largest = max(pixelWidth, pixelHeight)
        guard largest > maxDimension else { return image }

        let scale = maxDimension / largest
        let targetSize = CGSize(
            width: (pixelWidth * scale).rounded(),
            height: (pixelHeight * scale).rounded()
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
