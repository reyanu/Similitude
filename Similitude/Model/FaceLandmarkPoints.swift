import UIKit
import Vision

/// Vision-independent snapshot of a face's landmark geometry, in image
/// pixel coordinates. Keeping this as a plain struct makes every geometry
/// and scoring computation unit-testable without constructing Vision types.
struct FaceLandmarkPoints {
    /// Face bounding box in image pixels.
    let boundingBox: CGRect

    let faceContour: [CGPoint]
    let leftEye: [CGPoint]
    let rightEye: [CGPoint]
    let leftEyebrow: [CGPoint]
    let rightEyebrow: [CGPoint]
    let nose: [CGPoint]
    let outerLips: [CGPoint]
    let innerLips: [CGPoint]

    /// Converts a Vision observation into pixel-space landmark points.
    /// Vision's normalized coordinates have a bottom-left origin; y stays in
    /// that convention here — all downstream math uses distances and ratios,
    /// which only require internal consistency.
    static func from(_ observation: VNFaceObservation, imageSize: CGSize) -> FaceLandmarkPoints? {
        guard let landmarks = observation.landmarks else { return nil }

        let bbox = observation.boundingBox
        let pixelBox = CGRect(
            x: bbox.minX * imageSize.width,
            y: bbox.minY * imageSize.height,
            width: bbox.width * imageSize.width,
            height: bbox.height * imageSize.height
        )

        func convert(_ region: VNFaceLandmarkRegion2D?) -> [CGPoint] {
            guard let region else { return [] }
            return region.normalizedPoints.map { p in
                CGPoint(
                    x: (bbox.minX + CGFloat(p.x) * bbox.width) * imageSize.width,
                    y: (bbox.minY + CGFloat(p.y) * bbox.height) * imageSize.height
                )
            }
        }

        return FaceLandmarkPoints(
            boundingBox: pixelBox,
            faceContour: convert(landmarks.faceContour),
            leftEye: convert(landmarks.leftEye),
            rightEye: convert(landmarks.rightEye),
            leftEyebrow: convert(landmarks.leftEyebrow),
            rightEyebrow: convert(landmarks.rightEyebrow),
            nose: convert(landmarks.nose),
            outerLips: convert(landmarks.outerLips),
            innerLips: convert(landmarks.innerLips)
        )
    }
}

extension Array where Element == CGPoint {
    var centroid: CGPoint {
        guard !isEmpty else { return .zero }
        let sum = reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        return CGPoint(x: sum.x / CGFloat(count), y: sum.y / CGFloat(count))
    }

    var horizontalExtent: CGFloat {
        guard let minX = map(\.x).min(), let maxX = map(\.x).max() else { return 0 }
        return maxX - minX
    }

    var verticalExtent: CGFloat {
        guard let minY = map(\.y).min(), let maxY = map(\.y).max() else { return 0 }
        return maxY - minY
    }
}
