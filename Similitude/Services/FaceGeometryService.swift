import CoreGraphics
import Foundation

/// Dimensionless geometric measurements of a face. Every value is a ratio
/// normalized by inter-eye distance or face size, so metrics are invariant
/// to photo scale and comparable across people and photos.
/// A metric is nil when its landmark region was not detected.
struct FaceMetrics {
    var faceAspectRatio: Double?      // face width / face height
    var eyeSpacingRatio: Double?      // inter-eye distance / face width
    var eyeSizeRatio: Double?         // average eye width / inter-eye distance
    var eyeAspectRatio: Double?       // average eye height / eye width
    var eyebrowHeightRatio: Double?   // eyebrow-to-eye distance / inter-eye distance
    var noseLengthRatio: Double?      // nose vertical extent / face height
    var noseWidthRatio: Double?       // nose horizontal extent / inter-eye distance
    var mouthWidthRatio: Double?      // outer-lip width / inter-eye distance
    var lipFullnessRatio: Double?     // outer-lip height / outer-lip width
    var jawTaperRatio: Double?        // lower-jaw width / upper-contour width
    var symmetryScore: Double?        // 0 (asymmetric) … 1 (perfectly symmetric)
}

/// Computes explainable geometric metrics from landmark points.
struct FaceGeometryService {

    func metrics(from face: FaceLandmarkPoints) -> FaceMetrics {
        var m = FaceMetrics()

        let faceWidth = Double(face.boundingBox.width)
        let faceHeight = Double(face.boundingBox.height)
        if faceWidth > 0, faceHeight > 0 {
            m.faceAspectRatio = faceWidth / faceHeight
        }

        // Inter-eye distance is the master normalizer for facial features.
        let leftCenter = face.leftEye.centroid
        let rightCenter = face.rightEye.centroid
        let interEye = !face.leftEye.isEmpty && !face.rightEye.isEmpty
            ? Double(hypot(rightCenter.x - leftCenter.x, rightCenter.y - leftCenter.y))
            : 0

        if interEye > 0 {
            if faceWidth > 0 {
                m.eyeSpacingRatio = interEye / faceWidth
            }

            let leftWidth = Double(face.leftEye.horizontalExtent)
            let rightWidth = Double(face.rightEye.horizontalExtent)
            let avgEyeWidth = (leftWidth + rightWidth) / 2
            if avgEyeWidth > 0 {
                m.eyeSizeRatio = avgEyeWidth / interEye
                let avgEyeHeight = Double(face.leftEye.verticalExtent + face.rightEye.verticalExtent) / 2
                m.eyeAspectRatio = avgEyeHeight / avgEyeWidth
            }

            if !face.leftEyebrow.isEmpty, !face.rightEyebrow.isEmpty {
                let leftLift = Double(abs(face.leftEyebrow.centroid.y - leftCenter.y))
                let rightLift = Double(abs(face.rightEyebrow.centroid.y - rightCenter.y))
                m.eyebrowHeightRatio = (leftLift + rightLift) / 2 / interEye
            }

            if !face.nose.isEmpty {
                m.noseWidthRatio = Double(face.nose.horizontalExtent) / interEye
                if faceHeight > 0 {
                    m.noseLengthRatio = Double(face.nose.verticalExtent) / faceHeight
                }
            }

            if !face.outerLips.isEmpty {
                let mouthWidth = Double(face.outerLips.horizontalExtent)
                m.mouthWidthRatio = mouthWidth / interEye
                if mouthWidth > 0 {
                    m.lipFullnessRatio = Double(face.outerLips.verticalExtent) / mouthWidth
                }
            }
        }

        m.jawTaperRatio = jawTaper(face)
        m.symmetryScore = symmetry(face, interEye: interEye)
        return m
    }

    /// Ratio of lower-jaw width to upper-contour width. Vision's face
    /// contour runs from one ear down around the chin and up to the other
    /// ear, so quartile positions sample the jaw and the widest span.
    private func jawTaper(_ face: FaceLandmarkPoints) -> Double? {
        let contour = face.faceContour
        guard contour.count >= 8 else { return nil }
        let upperWidth = Double(contour.horizontalExtent)
        guard upperWidth > 0 else { return nil }
        let q1 = contour[contour.count / 4]
        let q3 = contour[(contour.count * 3) / 4]
        let jawWidth = Double(abs(q3.x - q1.x))
        return jawWidth / upperWidth
    }

    /// Horizontal mirror symmetry of paired regions about the face midline,
    /// normalized by inter-eye distance and mapped to 0…1.
    private func symmetry(_ face: FaceLandmarkPoints, interEye: Double) -> Double? {
        guard interEye > 0, !face.leftEye.isEmpty, !face.rightEye.isEmpty else { return nil }
        let midX = Double(face.leftEye.centroid.x + face.rightEye.centroid.x) / 2

        var deviations: [Double] = []
        func pairDeviation(_ left: [CGPoint], _ right: [CGPoint]) {
            guard !left.isEmpty, !right.isEmpty else { return }
            let leftOffset = midX - Double(left.centroid.x)
            let rightOffset = Double(right.centroid.x) - midX
            deviations.append(abs(leftOffset - rightOffset) / interEye)
        }

        pairDeviation(face.leftEye, face.rightEye)
        pairDeviation(face.leftEyebrow, face.rightEyebrow)

        // Nose and mouth centers should sit on the midline.
        for region in [face.nose, face.outerLips] where !region.isEmpty {
            deviations.append(abs(Double(region.centroid.x) - midX) / interEye)
        }

        guard !deviations.isEmpty else { return nil }
        let mean = deviations.reduce(0, +) / Double(deviations.count)
        return max(0, 1 - mean * 2)
    }
}
