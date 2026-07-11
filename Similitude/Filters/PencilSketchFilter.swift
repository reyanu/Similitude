import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Deterministic pencil sketch:
/// grayscale → mild denoise → edge detection → single inversion →
/// blend with light grayscale structure → controlled contrast → sharpening →
/// luminance validation with a guaranteed non-blank fallback.
///
/// Parameters are fixed constants within the spec's ranges — never tuned at
/// runtime and never randomized.
struct PencilSketchFilter: ArtisticFilter {
    let kind = ArtisticFilterKind.pencilSketch

    // Fixed pipeline parameters (within spec ranges).
    private static let edgeIntensity: Float = 1.6
    private static let denoiseLevel: Float = 0.02
    private static let gaussianBlurRadius: Float = 1.5
    private static let contrast: Float = 1.25
    private static let brightness: Float = 0.05
    private static let sharpness: Float = 0.4

    /// Intermediate stages preserved in development builds for diagnosis.
    struct Intermediates {
        var normalizedInput: UIImage?
        var grayscale: UIImage?
        var edgeMap: UIImage?
        var invertedEdgeMap: UIImage?
        var blended: UIImage?
        var final: UIImage?
    }

    #if DEBUG
    static var lastIntermediates = Intermediates()
    #endif

    func apply(to image: UIImage) throws -> UIImage {
        try autoreleasepool {
            let input = try image.filterInput()
            #if DEBUG
            var intermediates = Intermediates()
            intermediates.normalizedInput = try? FilterContext.renderUIImage(input)
            #endif

            // Grayscale
            let grayFilter = CIFilter.colorControls()
            grayFilter.inputImage = input
            grayFilter.saturation = 0
            guard let grayscale = grayFilter.outputImage else {
                throw ArtisticFilterError.renderingFailed
            }
            #if DEBUG
            intermediates.grayscale = try? FilterContext.renderUIImage(grayscale)
            #endif

            // Mild denoise before edge detection to suppress sensor noise.
            let denoise = CIFilter.noiseReduction()
            denoise.inputImage = grayscale
            denoise.noiseLevel = Self.denoiseLevel
            denoise.sharpness = 0.2
            let denoised = denoise.outputImage ?? grayscale

            // Slight blur softens micro-texture so edges trace real features.
            let blur = CIFilter.gaussianBlur()
            blur.inputImage = denoised
            blur.radius = Self.gaussianBlurRadius
            let smoothed = (blur.outputImage ?? denoised).cropped(to: input.extent)

            // Edge detection (bright lines on black).
            let edges = CIFilter.edges()
            edges.inputImage = smoothed
            edges.intensity = Self.edgeIntensity
            guard let edgeMap = edges.outputImage?.cropped(to: input.extent) else {
                throw ArtisticFilterError.renderingFailed
            }
            #if DEBUG
            intermediates.edgeMap = try? FilterContext.renderUIImage(edgeMap)
            #endif

            // Invert exactly once: dark lines on white paper.
            let invert = CIFilter.colorInvert()
            invert.inputImage = edgeMap
            guard let invertedEdges = invert.outputImage else {
                throw ArtisticFilterError.renderingFailed
            }
            #if DEBUG
            intermediates.invertedEdgeMap = try? FilterContext.renderUIImage(invertedEdges)
            #endif

            // Light grayscale structure: lifted shading so the sketch keeps
            // gentle tonal form rather than pure line art.
            let lift = CIFilter.colorControls()
            lift.inputImage = grayscale
            lift.brightness = 0.35
            lift.contrast = 0.85
            lift.saturation = 0
            let lightStructure = lift.outputImage ?? grayscale

            // Multiply keeps the white paper and darkens only where lines are.
            let blend = CIFilter.multiplyBlendMode()
            blend.inputImage = invertedEdges
            blend.backgroundImage = lightStructure
            guard let blended = blend.outputImage?.cropped(to: input.extent) else {
                throw ArtisticFilterError.renderingFailed
            }
            #if DEBUG
            intermediates.blended = try? FilterContext.renderUIImage(blended)
            #endif

            // Controlled contrast and brightness.
            let tone = CIFilter.colorControls()
            tone.inputImage = blended
            tone.contrast = Self.contrast
            tone.brightness = Self.brightness
            tone.saturation = 0
            let toned = tone.outputImage ?? blended

            // Controlled sharpening.
            let sharpen = CIFilter.sharpenLuminance()
            sharpen.inputImage = toned
            sharpen.sharpness = Self.sharpness
            let finalCI = (sharpen.outputImage ?? toned).cropped(to: input.extent)

            let result = try FilterContext.renderUIImage(finalCI, scale: image.scale)
            #if DEBUG
            intermediates.final = result
            Self.lastIntermediates = intermediates
            #endif

            // Luminance validation: reject blank-white, black-fill, or flat
            // output and substitute the safe fallback. Never return blank.
            if let stats = ImageStatistics.compute(for: result), stats.isSuspicious {
                return try safeFallback(input: input, grayscale: grayscale, invertedEdges: invertedEdges, scale: image.scale)
            }
            return result
        }
    }

    /// Safe fallback: light grayscale + dark edge overlay + mild contrast +
    /// mild sharpening. Structurally guaranteed to be neither blank nor black.
    private func safeFallback(
        input: CIImage,
        grayscale: CIImage,
        invertedEdges: CIImage,
        scale: CGFloat
    ) throws -> UIImage {
        let lighten = CIFilter.colorControls()
        lighten.inputImage = grayscale
        lighten.brightness = 0.25
        lighten.contrast = 1.05
        lighten.saturation = 0
        let lightGray = lighten.outputImage ?? grayscale

        let blend = CIFilter.multiplyBlendMode()
        blend.inputImage = invertedEdges
        blend.backgroundImage = lightGray
        let combined = (blend.outputImage ?? lightGray).cropped(to: input.extent)

        let sharpen = CIFilter.sharpenLuminance()
        sharpen.inputImage = combined
        sharpen.sharpness = 0.3
        let finalCI = (sharpen.outputImage ?? combined).cropped(to: input.extent)

        return try FilterContext.renderUIImage(finalCI, scale: scale)
    }
}
