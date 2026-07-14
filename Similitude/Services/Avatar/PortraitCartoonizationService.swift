import UIKit
import CoreML
import CoreVideo
import CoreImage

enum CartoonizationError: LocalizedError {
    case modelLoadFailed(String)
    case unsupportedModelInterface(String)
    case preprocessingFailed
    case inferenceFailed(String)
    case postprocessingFailed

    var errorDescription: String? {
        switch self {
        case .modelLoadFailed(let reason):
            return "The AI model could not be loaded: \(reason)"
        case .unsupportedModelInterface(let detail):
            return "The installed model has an unsupported interface: \(detail)"
        case .preprocessingFailed:
            return "The photo could not be prepared for the AI model."
        case .inferenceFailed(let reason):
            return "AI portrait generation failed: \(reason)"
        case .postprocessingFailed:
            return "The AI portrait result could not be read."
        }
    }
}

/// Runs the installed Photo2Cartoon Core ML model on a portrait. Real
/// on-device inference only — this type has no Core Image fallback path.
final class PortraitCartoonizationService {

    private let model: MLModel
    private let inputName: String
    private let outputName: String
    private let inputSize: CGSize

    /// Loads the compiled model and inspects its image interface.
    init(modelDirectoryURL: URL) throws {
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all // Neural Engine where supported
        do {
            model = try MLModel(contentsOf: modelDirectoryURL, configuration: configuration)
        } catch {
            throw CartoonizationError.modelLoadFailed(error.localizedDescription)
        }

        let inputs = model.modelDescription.inputDescriptionsByName
        guard let (name, description) = inputs.first(where: { $0.value.type == .image }),
              let constraint = description.imageConstraint else {
            throw CartoonizationError.unsupportedModelInterface(
                "no image input (inputs: \(inputs.keys.sorted().joined(separator: ", ")))"
            )
        }
        inputName = name
        inputSize = CGSize(width: constraint.pixelsWide, height: constraint.pixelsHigh)

        let outputs = model.modelDescription.outputDescriptionsByName
        guard let output = outputs.first(where: { $0.value.type == .image }) else {
            throw CartoonizationError.unsupportedModelInterface(
                "no image output (outputs: \(outputs.keys.sorted().joined(separator: ", ")))"
            )
        }
        outputName = output.key
    }

    /// Cartoonizes a portrait. Returns the stylized image and the inference
    /// duration. Memory-intensive work is wrapped in autorelease pools so a
    /// 6 GB device never accumulates intermediate buffers.
    func cartoonize(_ image: UIImage) throws -> (image: UIImage, inferenceSeconds: Double) {
        let pixelBuffer = try autoreleasepool { try makeInputBuffer(from: image) }

        let start = CFAbsoluteTimeGetCurrent()
        let outputBuffer: CVPixelBuffer = try autoreleasepool {
            let provider = try MLDictionaryFeatureProvider(
                dictionary: [inputName: MLFeatureValue(pixelBuffer: pixelBuffer)]
            )
            let prediction: MLFeatureProvider
            do {
                prediction = try model.prediction(from: provider)
            } catch {
                throw CartoonizationError.inferenceFailed(error.localizedDescription)
            }
            guard let buffer = prediction.featureValue(for: outputName)?.imageBufferValue else {
                throw CartoonizationError.postprocessingFailed
            }
            return buffer
        }
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        let result = try autoreleasepool { try makeUIImage(from: outputBuffer) }
        return (result, elapsed)
    }

    // MARK: Pre/post processing

    /// Center-crops to the model's aspect ratio and scales to its input size.
    private func makeInputBuffer(from image: UIImage) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
        ]
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(inputSize.width),
            Int(inputSize.height),
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &buffer
        )
        guard let pixelBuffer = buffer else { throw CartoonizationError.preprocessingFailed }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: Int(inputSize.width),
            height: Int(inputSize.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                | CGBitmapInfo.byteOrder32Little.rawValue
        ), let cgImage = image.cgImage else {
            throw CartoonizationError.preprocessingFailed
        }

        // Aspect-fill draw centered in the model's input frame.
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let scale = max(inputSize.width / imageSize.width, inputSize.height / imageSize.height)
        let drawSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(
            x: (inputSize.width - drawSize.width) / 2,
            y: (inputSize.height - drawSize.height) / 2
        )
        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(origin: origin, size: drawSize))
        return pixelBuffer
    }

    private func makeUIImage(from buffer: CVPixelBuffer) throws -> UIImage {
        let ciImage = CIImage(cvPixelBuffer: buffer)
        guard let cgImage = FilterContext.shared.createCGImage(ciImage, from: ciImage.extent) else {
            throw CartoonizationError.postprocessingFailed
        }
        return UIImage(cgImage: cgImage)
    }
}
