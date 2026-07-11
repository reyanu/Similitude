import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

enum ArtisticFilterError: Error {
    case invalidInput
    case renderingFailed
}

/// The V1 artistic filter set.
enum ArtisticFilterKind: String, CaseIterable, Identifiable {
    case pencilSketch
    case posterArt
    case softCartoon

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pencilSketch: return "Pencil Sketch"
        case .posterArt: return "Poster Art"
        case .softCartoon: return "Soft Cartoon"
        }
    }

    var previewAssetName: String {
        switch self {
        case .pencilSketch: return "preview_pencil_sketch"
        case .posterArt: return "preview_poster_art"
        case .softCartoon: return "preview_soft_cartoon"
        }
    }
}

/// A deterministic image-to-image artistic filter. Implementations must be
/// parameter-stable (no random tuning) and must never return a blank image.
protocol ArtisticFilter {
    var kind: ArtisticFilterKind { get }
    func apply(to image: UIImage) throws -> UIImage
}

/// Shared Core Image context. Creating CIContexts is expensive; one shared
/// software-independent context serves all filters.
enum FilterContext {
    static let shared = CIContext(options: [.cacheIntermediates: false])

    static func renderUIImage(_ ciImage: CIImage, scale: CGFloat = 1) throws -> UIImage {
        guard let cgImage = shared.createCGImage(ciImage, from: ciImage.extent) else {
            throw ArtisticFilterError.renderingFailed
        }
        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }
}

extension UIImage {
    /// A CIImage with orientation baked in, ready for filtering.
    func filterInput() throws -> CIImage {
        if let cg = cgImage {
            return CIImage(cgImage: cg).oriented(CGImagePropertyOrientation(imageOrientation))
        }
        if let ci = ciImage {
            return ci.oriented(CGImagePropertyOrientation(imageOrientation))
        }
        throw ArtisticFilterError.invalidInput
    }
}

extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
