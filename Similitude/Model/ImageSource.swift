import Foundation

/// Where a portrait photo came from. Every source flows through the same
/// normalization pipeline before Vision analysis.
enum ImageSource {
    case cameraFront
    case cameraRear
    case photoLibrary

    /// Front-camera captures arrive mirrored and must be flipped so that
    /// geometry (eye left/right, yaw sign) is consistent across sources.
    var isMirrored: Bool {
        self == .cameraFront
    }

    var debugLabel: String {
        switch self {
        case .cameraFront: return "front camera"
        case .cameraRear: return "rear camera"
        case .photoLibrary: return "library"
        }
    }
}
