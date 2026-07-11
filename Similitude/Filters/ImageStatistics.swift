import UIKit
import CoreImage

/// Luminance statistics computed on a downsampled copy of an image.
/// Used to validate filter output before it is shown to the user.
struct ImageStatistics {
    let nearWhiteRatio: Double
    let nearBlackRatio: Double
    let luminanceVariance: Double

    /// Thresholds from the Pencil Sketch safety spec.
    var isSuspicious: Bool {
        nearWhiteRatio > 0.92 ||
        nearBlackRatio > 0.60 ||
        luminanceVariance < 0.002
    }

    /// Computes statistics on a 64×64 downsample — cheap and sufficient
    /// for blank/black detection.
    static func compute(for image: UIImage) -> ImageStatistics? {
        guard let cgImage = image.cgImage else { return nil }

        let side = 64
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: nil,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: side,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }

        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
        guard let data = context.data else { return nil }

        let pixels = data.bindMemory(to: UInt8.self, capacity: side * side)
        let count = side * side

        var whiteCount = 0
        var blackCount = 0
        var sum = 0.0
        var sumSquares = 0.0

        for i in 0..<count {
            let v = Double(pixels[i]) / 255.0
            if v > 0.92 { whiteCount += 1 }
            if v < 0.10 { blackCount += 1 }
            sum += v
            sumSquares += v * v
        }

        let mean = sum / Double(count)
        let variance = max(0, sumSquares / Double(count) - mean * mean)

        return ImageStatistics(
            nearWhiteRatio: Double(whiteCount) / Double(count),
            nearBlackRatio: Double(blackCount) / Double(count),
            luminanceVariance: variance
        )
    }
}
