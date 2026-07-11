import UIKit
import Vision

enum FaceNormalizationError: Error {
    case invalidImage
    case renderingFailed
}

/// Normalizes every incoming photo — front camera, rear camera, or library —
/// into a consistent, upright, un-mirrored pixel buffer before any Vision
/// analysis. This is the single entry point for all photo sources.
struct FaceNormalizationService {

    /// Maximum pixel dimension for analysis images. Keeps Vision fast and
    /// memory bounded; full resolution is only used at export time.
    static let analysisMaxDimension: CGFloat = 2048

    /// Target inter-eye distance (in points) after geometric normalization.
    static let normalizedInterEyeDistance: CGFloat = 160

    /// Step 1 of the pipeline: produce an image whose pixels are upright
    /// (orientation `.up`) and un-mirrored, downscaled to a bounded size.
    /// After this, Vision is always given `CGImagePropertyOrientation.up`.
    func normalizedPortraitImage(
        from image: UIImage,
        source: ImageSource
    ) throws -> UIImage {
        guard image.size.width > 0, image.size.height > 0 else {
            throw FaceNormalizationError.invalidImage
        }

        let maxDimension = max(image.size.width, image.size.height)
        let scale = min(1, Self.analysisMaxDimension / maxDimension)
        let targetSize = CGSize(
            width: (image.size.width * scale).rounded(),
            height: (image.size.height * scale).rounded()
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)

        // Drawing the UIImage bakes `imageOrientation` into the pixels.
        let upright = renderer.image { context in
            if source.isMirrored {
                context.cgContext.translateBy(x: targetSize.width, y: 0)
                context.cgContext.scaleBy(x: -1, y: 1)
            }
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        guard upright.cgImage != nil else {
            throw FaceNormalizationError.renderingFailed
        }
        return upright
    }

    /// Step 2 (after detection): geometrically align a face so eyes are
    /// horizontal and inter-eye distance matches the normalized constant.
    /// Falls back to a plain face-region crop when eye landmarks are missing.
    func alignedPortrait(
        from image: UIImage,
        observation: VNFaceObservation
    ) throws -> UIImage {
        guard let cgImage = image.cgImage else {
            throw FaceNormalizationError.invalidImage
        }

        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let faceRect = Self.imageRect(fromNormalized: observation.boundingBox, imageSize: imageSize)

        var rollAngle: CGFloat = 0
        var eyeDistance: CGFloat = 0

        if let landmarks = observation.landmarks,
           let left = landmarks.leftPupil ?? landmarks.leftEye,
           let right = landmarks.rightPupil ?? landmarks.rightEye {
            let leftCenter = Self.averagePoint(of: left, boundingBox: observation.boundingBox, imageSize: imageSize)
            let rightCenter = Self.averagePoint(of: right, boundingBox: observation.boundingBox, imageSize: imageSize)
            rollAngle = atan2(rightCenter.y - leftCenter.y, rightCenter.x - leftCenter.x)
            eyeDistance = hypot(rightCenter.x - leftCenter.x, rightCenter.y - leftCenter.y)
        }

        // Crop with generous margin around the face, then rotate/scale.
        let margin = faceRect.width * 0.55
        let cropRect = faceRect.insetBy(dx: -margin, dy: -margin)
            .intersection(CGRect(origin: .zero, size: imageSize))
        guard let croppedCG = cgImage.cropping(to: cropRect) else {
            throw FaceNormalizationError.renderingFailed
        }
        let cropped = UIImage(cgImage: croppedCG)

        let scale: CGFloat = eyeDistance > 0
            ? Self.normalizedInterEyeDistance / eyeDistance
            : min(1, 512 / max(cropped.size.width, cropped.size.height))

        let outputSize = CGSize(
            width: max(64, (cropped.size.width * scale).rounded()),
            height: max(64, (cropped.size.height * scale).rounded())
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: outputSize, format: format)
        return renderer.image { context in
            let cg = context.cgContext
            cg.translateBy(x: outputSize.width / 2, y: outputSize.height / 2)
            if abs(rollAngle) > 0.001 {
                cg.rotate(by: -rollAngle)
            }
            cg.scaleBy(x: scale, y: scale)
            cropped.draw(in: CGRect(
                x: -cropped.size.width / 2,
                y: -cropped.size.height / 2,
                width: cropped.size.width,
                height: cropped.size.height
            ))
        }
    }

    // MARK: Coordinate helpers

    /// Converts a Vision normalized rect (origin bottom-left) into UIKit
    /// image coordinates (origin top-left).
    static func imageRect(fromNormalized rect: CGRect, imageSize: CGSize) -> CGRect {
        CGRect(
            x: rect.minX * imageSize.width,
            y: (1 - rect.maxY) * imageSize.height,
            width: rect.width * imageSize.width,
            height: rect.height * imageSize.height
        )
    }

    /// Average of a landmark region's points, in UIKit image coordinates.
    static func averagePoint(
        of region: VNFaceLandmarkRegion2D,
        boundingBox: CGRect,
        imageSize: CGSize
    ) -> CGPoint {
        let points = region.normalizedPoints
        guard !points.isEmpty else { return .zero }
        var sum = CGPoint.zero
        for p in points {
            // Landmark points are normalized within the face bounding box.
            let nx = boundingBox.minX + CGFloat(p.x) * boundingBox.width
            let ny = boundingBox.minY + CGFloat(p.y) * boundingBox.height
            sum.x += nx * imageSize.width
            sum.y += (1 - ny) * imageSize.height
        }
        return CGPoint(x: sum.x / CGFloat(points.count), y: sum.y / CGFloat(points.count))
    }
}
