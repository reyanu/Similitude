import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Poster Art: vivid posterized color regions with strong edge definition.
/// Boosts vibrance before posterization so regions stay colorful rather than
/// collapsing into muddy browns and grays.
struct PosterArtFilter: ArtisticFilter {
    let kind = ArtisticFilterKind.posterArt

    private static let posterizeLevels: Float = 6
    private static let vibranceAmount: Float = 0.6
    private static let saturationBoost: Float = 1.25
    private static let edgeIntensity: Float = 1.2

    func apply(to image: UIImage) throws -> UIImage {
        try autoreleasepool {
            let input = try image.filterInput()

            // Lift color first so posterized regions are vivid, not muddy.
            let vibrance = CIFilter.vibrance()
            vibrance.inputImage = input
            vibrance.amount = Self.vibranceAmount
            let vivid = vibrance.outputImage ?? input

            let color = CIFilter.colorControls()
            color.inputImage = vivid
            color.saturation = Self.saturationBoost
            color.contrast = 1.1
            let colorful = color.outputImage ?? vivid

            // Gentle smoothing keeps posterized regions clean while the small
            // radius preserves eyes and facial detail.
            let blur = CIFilter.gaussianBlur()
            blur.inputImage = colorful
            blur.radius = 1.2
            let smoothed = (blur.outputImage ?? colorful).cropped(to: input.extent)

            let posterize = CIFilter.colorPosterize()
            posterize.inputImage = smoothed
            posterize.levels = Self.posterizeLevels
            guard let posterized = posterize.outputImage?.cropped(to: input.extent) else {
                throw ArtisticFilterError.renderingFailed
            }

            // Dark edge lines multiplied over the posterized color.
            let edges = CIFilter.edges()
            edges.inputImage = input
            edges.intensity = Self.edgeIntensity
            let edgeMap = edges.outputImage?.cropped(to: input.extent)

            var finalCI = posterized
            if let edgeMap {
                let invert = CIFilter.colorInvert()
                invert.inputImage = edgeMap
                if let darkLines = invert.outputImage {
                    let blend = CIFilter.multiplyBlendMode()
                    blend.inputImage = darkLines
                    blend.backgroundImage = posterized
                    finalCI = (blend.outputImage ?? posterized).cropped(to: input.extent)
                }
            }

            let result = try FilterContext.renderUIImage(finalCI, scale: image.scale)
            if let stats = ImageStatistics.compute(for: result), stats.isSuspicious {
                // Fall back to the vivid posterized image without edge overlay.
                return try FilterContext.renderUIImage(posterized, scale: image.scale)
            }
            return result
        }
    }
}
