import UIKit
import Vision
import os

/// Why a photo was not accepted, with a specific user-facing message for each
/// case — never one generic error for every failure.
enum FaceValidationError: LocalizedError {
    case noFaceDetected
    case faceTooSmall
    case poseTooAngled
    case missingPrimaryLandmarks
    case imageTooDark

    var errorDescription: String? {
        switch self {
        case .noFaceDetected:
            return "No face detected. Try a clearer, front-facing photo."
        case .faceTooSmall:
            return "Move closer to the camera so the face fills more of the frame."
        case .poseTooAngled:
            return "Keep the face mostly forward, then try again."
        case .missingPrimaryLandmarks:
            return "The face is hard to read. Use a brighter photo with the face clearly visible."
        case .imageTooDark:
            return "Use a brighter photo."
        }
    }
}

/// A validated, accepted face ready for downstream analysis.
struct DetectedFace {
    let observation: VNFaceObservation
    /// The upright, un-mirrored image the observation was made on.
    let normalizedImage: UIImage
    let source: ImageSource
}

/// Detects and validates faces using Vision landmarks. Tolerant thresholds:
/// a reasonably frontal, sufficiently large face with primary landmarks is
/// accepted — optional landmark regions are never required.
struct FaceDetectionService {

    // Tolerant acceptance thresholds (radians / area ratio).
    static let maxAbsoluteYaw: Double = 0.40
    static let maxAbsoluteRoll: Double = 0.35
    static let minFaceAreaRatio: Double = 0.12

    private static let log = Logger(subsystem: "com.rymoslite.similitude", category: "FaceDetection")
    private let normalizer = FaceNormalizationService()

    /// Full pipeline: normalize → detect landmarks → validate pose/size.
    func detectFace(in image: UIImage, source: ImageSource) throws -> DetectedFace {
        let normalized = try normalizer.normalizedPortraitImage(from: image, source: source)
        guard let cgImage = normalized.cgImage else {
            throw FaceNormalizationError.renderingFailed
        }

        let request = VNDetectFaceLandmarksRequest()
        // Pixels are already upright and un-mirrored, so orientation is .up.
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
        try handler.perform([request])

        let observations = request.results ?? []
        logDiagnostics(image: image, normalized: normalized, source: source, observations: observations)

        guard let best = observations.max(by: {
            $0.boundingBox.width * $0.boundingBox.height <
            $1.boundingBox.width * $1.boundingBox.height
        }) else {
            throw FaceValidationError.noFaceDetected
        }

        try validate(best, source: source)
        return DetectedFace(observation: best, normalizedImage: normalized, source: source)
    }

    /// Validation is intentionally tolerant: valid rectangle, primary
    /// landmarks, sufficient size, reasonably frontal pose.
    private func validate(_ face: VNFaceObservation, source: ImageSource) throws {
        let areaRatio = Double(face.boundingBox.width * face.boundingBox.height)
        if areaRatio < Self.minFaceAreaRatio {
            Self.log.debug("Rejected [\(source.debugLabel)]: face area \(areaRatio, format: .fixed(precision: 3)) < \(Self.minFaceAreaRatio)")
            throw FaceValidationError.faceTooSmall
        }

        if let yaw = face.yaw?.doubleValue, abs(yaw) > Self.maxAbsoluteYaw {
            Self.log.debug("Rejected [\(source.debugLabel)]: |yaw| \(abs(yaw), format: .fixed(precision: 3)) > \(Self.maxAbsoluteYaw)")
            throw FaceValidationError.poseTooAngled
        }
        if let roll = face.roll?.doubleValue, abs(roll) > Self.maxAbsoluteRoll {
            Self.log.debug("Rejected [\(source.debugLabel)]: |roll| \(abs(roll), format: .fixed(precision: 3)) > \(Self.maxAbsoluteRoll)")
            throw FaceValidationError.poseTooAngled
        }

        // Primary landmarks only: both eyes plus nose or outer lips.
        guard let landmarks = face.landmarks,
              landmarks.leftEye != nil,
              landmarks.rightEye != nil,
              landmarks.nose != nil || landmarks.outerLips != nil
        else {
            Self.log.debug("Rejected [\(source.debugLabel)]: primary landmarks missing")
            throw FaceValidationError.missingPrimaryLandmarks
        }
    }

    // MARK: Diagnostics

    private func logDiagnostics(
        image: UIImage,
        normalized: UIImage,
        source: ImageSource,
        observations: [VNFaceObservation]
    ) {
        #if DEBUG
        Self.log.debug("""
        Face detection diagnostics:
          source: \(source.debugLabel)
          UIImage orientation: \(image.imageOrientation.rawValue) → normalized to .up
          Vision orientation: up
          mirrored input: \(source.isMirrored)
          normalized size: \(Int(normalized.size.width))x\(Int(normalized.size.height))
          detected face count: \(observations.count)
        """)
        for (index, face) in observations.enumerated() {
            let area = face.boundingBox.width * face.boundingBox.height
            let regions = Self.landmarkRegionNames(face.landmarks)
            Self.log.debug("""
              face[\(index)]:
                boundingBox: \(String(describing: face.boundingBox))
                yaw: \(face.yaw?.doubleValue ?? .nan, format: .fixed(precision: 3))
                roll: \(face.roll?.doubleValue ?? .nan, format: .fixed(precision: 3))
                faceAreaRatio: \(Double(area), format: .fixed(precision: 3))
                landmarks: \(regions.joined(separator: ", "))
            """)
        }
        #endif
    }

    static func landmarkRegionNames(_ landmarks: VNFaceLandmarks2D?) -> [String] {
        guard let l = landmarks else { return ["none"] }
        var names: [String] = []
        if l.faceContour != nil { names.append("faceContour") }
        if l.leftEye != nil { names.append("leftEye") }
        if l.rightEye != nil { names.append("rightEye") }
        if l.leftEyebrow != nil { names.append("leftEyebrow") }
        if l.rightEyebrow != nil { names.append("rightEyebrow") }
        if l.nose != nil { names.append("nose") }
        if l.noseCrest != nil { names.append("noseCrest") }
        if l.outerLips != nil { names.append("outerLips") }
        if l.innerLips != nil { names.append("innerLips") }
        if l.leftPupil != nil { names.append("leftPupil") }
        if l.rightPupil != nil { names.append("rightPupil") }
        return names.isEmpty ? ["none"] : names
    }
}
