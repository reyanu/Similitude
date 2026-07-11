import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Soft Cartoon: smoothed skin, brightened facial tones, clear eyes, and
/// gentle edge enhancement — visibly stylized but still recognizable.
struct SoftCartoonFilter: ArtisticFilter {
    let kind = ArtisticFilterKind.softCartoon

    func apply(to image: UIImage) throws -> UIImage {
        try autoreleasepool {
            let input = try image.filterInput()

            // Noise reduction plus a soft blur smooths skin texture.
            let denoise = CIFilter.noiseReduction()
            denoise.inputImage = input
            denoise.noiseLevel = 0.04
            denoise.sharpness = 0.1
            let denoised = denoise.outputImage ?? input

            let smooth = CIFilter.gaussianBlur()
            smooth.inputImage = denoised
            smooth.radius = 2.0
            let smoothed = (smooth.outputImage ?? denoised).cropped(to: input.extent)

            // Recover structure: unsharp mask restores eyes and defining
            // lines that the smoothing softened.
            let structure = CIFilter.unsharpMask()
            structure.inputImage = smoothed
            structure.radius = 3.0
            structure.intensity = 0.8
            let structured = (structure.outputImage ?? smoothed).cropped(to: input.extent)

            // Brighter, warmer tones — never dark or muddy.
            let tone = CIFilter.colorControls()
            tone.inputImage = structured
            tone.brightness = 0.06
            tone.contrast = 1.08
            tone.saturation = 1.2
            let toned = tone.outputImage ?? structured

            let vibrance = CIFilter.vibrance()
            vibrance.inputImage = toned
            vibrance.amount = 0.3
            let finalColor = (vibrance.outputImage ?? toned).cropped(to: input.extent)

            // Gentle edge enhancement for the stylized look.
            let edges = CIFilter.edges()
            edges.inputImage = input
            edges.intensity = 0.7
            var finalCI = finalColor
            if let edgeMap = edges.outputImage?.cropped(to: input.extent) {
                let invert = CIFilter.colorInvert()
                invert.inputImage = edgeMap
                if let darkLines = invert.outputImage {
                    // Soft-light keeps lines gentle rather than harsh ink.
                    let blend = CIFilter.softLightBlendMode()
                    blend.inputImage = darkLines
                    blend.backgroundImage = finalColor
                    finalCI = (blend.outputImage ?? finalColor).cropped(to: input.extent)
                }
            }

            let result = try FilterContext.renderUIImage(finalCI, scale: image.scale)
            if let stats = ImageStatistics.compute(for: result), stats.isSuspicious {
                // Fall back to the brightened smoothed image without edges.
                return try FilterContext.renderUIImage(finalColor, scale: image.scale)
            }
            return result
        }
    }
}
