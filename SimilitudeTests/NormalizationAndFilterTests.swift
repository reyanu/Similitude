import XCTest
import UIKit
@testable import Similitude

final class NormalizationAndFilterTests: XCTestCase {

    // MARK: Test image helpers

    /// A synthetic face-like portrait: skin-tone oval with dark eyes, nose
    /// line, and mouth on a light background. Enough structure to exercise
    /// filters deterministically without bundling photo fixtures.
    private func syntheticPortrait(size: CGSize = CGSize(width: 400, height: 500)) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let cg = ctx.cgContext
            UIColor(white: 0.93, alpha: 1).setFill()
            cg.fill(CGRect(origin: .zero, size: size))

            UIColor(red: 0.87, green: 0.72, blue: 0.60, alpha: 1).setFill()
            cg.fillEllipse(in: CGRect(x: 80, y: 90, width: 240, height: 320))

            UIColor(white: 0.15, alpha: 1).setFill()
            cg.fillEllipse(in: CGRect(x: 140, y: 200, width: 34, height: 20))
            cg.fillEllipse(in: CGRect(x: 226, y: 200, width: 34, height: 20))
            cg.fill(CGRect(x: 195, y: 240, width: 10, height: 60))
            cg.fill(CGRect(x: 160, y: 330, width: 80, height: 12))
        }
    }

    private func rotatedImage(_ image: UIImage, orientation: UIImage.Orientation) -> UIImage {
        guard let cg = image.cgImage else { return image }
        return UIImage(cgImage: cg, scale: 1, orientation: orientation)
    }

    // MARK: Normalization

    func testNormalizationProducesUprightPixels() throws {
        let service = FaceNormalizationService()
        let base = syntheticPortrait()
        let rotated = rotatedImage(base, orientation: .right)

        let normalized = try service.normalizedPortraitImage(from: rotated, source: .photoLibrary)
        XCTAssertEqual(normalized.imageOrientation, .up)
        // .right orientation swaps display dimensions; normalization must
        // bake that in so pixel size matches the displayed size.
        XCTAssertEqual(normalized.size.width, base.size.height, accuracy: 2)
        XCTAssertEqual(normalized.size.height, base.size.width, accuracy: 2)
    }

    func testNormalizationUnmirrorsFrontCamera() throws {
        let service = FaceNormalizationService()
        // Asymmetric image: left half dark, right half light.
        let size = CGSize(width: 100, height: 100)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let asymmetric = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.black.setFill()
            ctx.cgContext.fill(CGRect(x: 0, y: 0, width: 50, height: 100))
            UIColor.white.setFill()
            ctx.cgContext.fill(CGRect(x: 50, y: 0, width: 50, height: 100))
        }

        let library = try service.normalizedPortraitImage(from: asymmetric, source: .photoLibrary)
        let front = try service.normalizedPortraitImage(from: asymmetric, source: .cameraFront)

        XCTAssertNotEqual(
            averageLuminanceLeftHalf(library),
            averageLuminanceLeftHalf(front),
            accuracy: 0.2,
            "Front-camera normalization must horizontally flip the image"
        )
    }

    func testNormalizationRejectsEmptyImage() {
        let service = FaceNormalizationService()
        XCTAssertThrowsError(try service.normalizedPortraitImage(from: UIImage(), source: .photoLibrary))
    }

    func testNormalizationCapsAnalysisDimension() throws {
        let service = FaceNormalizationService()
        let large = syntheticPortrait(size: CGSize(width: 4000, height: 5000))
        let normalized = try service.normalizedPortraitImage(from: large, source: .photoLibrary)
        XCTAssertLessThanOrEqual(
            max(normalized.size.width, normalized.size.height),
            FaceNormalizationService.analysisMaxDimension + 1
        )
    }

    // MARK: Filter safety

    func testPencilSketchNeverBlankOrBlack() throws {
        let result = try PencilSketchFilter().apply(to: syntheticPortrait())
        let stats = try XCTUnwrap(ImageStatistics.compute(for: result))
        XCTAssertLessThanOrEqual(stats.nearWhiteRatio, 0.92, "Pencil Sketch must not be blank white")
        XCTAssertLessThanOrEqual(stats.nearBlackRatio, 0.60, "Pencil Sketch must not be a black fill")
        XCTAssertGreaterThan(stats.luminanceVariance, 0.002, "Pencil Sketch must have visible structure")
    }

    func testPosterArtProducesNonSuspiciousOutput() throws {
        let result = try PosterArtFilter().apply(to: syntheticPortrait())
        let stats = try XCTUnwrap(ImageStatistics.compute(for: result))
        XCTAssertFalse(stats.isSuspicious)
    }

    func testSoftCartoonProducesNonSuspiciousOutput() throws {
        let result = try SoftCartoonFilter().apply(to: syntheticPortrait())
        let stats = try XCTUnwrap(ImageStatistics.compute(for: result))
        XCTAssertFalse(stats.isSuspicious)
    }

    func testFiltersPreserveImageDimensions() throws {
        let input = syntheticPortrait()
        for filter in [PencilSketchFilter() as ArtisticFilter, PosterArtFilter(), SoftCartoonFilter()] {
            let output = try filter.apply(to: input)
            XCTAssertEqual(output.size.width, input.size.width, accuracy: 2)
            XCTAssertEqual(output.size.height, input.size.height, accuracy: 2)
        }
    }

    // MARK: Statistics

    func testStatisticsDetectBlankWhite() throws {
        let size = CGSize(width: 64, height: 64)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let white = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.white.setFill()
            ctx.cgContext.fill(CGRect(origin: .zero, size: size))
        }
        let stats = try XCTUnwrap(ImageStatistics.compute(for: white))
        XCTAssertTrue(stats.isSuspicious)
        XCTAssertGreaterThan(stats.nearWhiteRatio, 0.92)
    }

    func testStatisticsDetectBlackFill() throws {
        let size = CGSize(width: 64, height: 64)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let black = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.black.setFill()
            ctx.cgContext.fill(CGRect(origin: .zero, size: size))
        }
        let stats = try XCTUnwrap(ImageStatistics.compute(for: black))
        XCTAssertTrue(stats.isSuspicious)
        XCTAssertGreaterThan(stats.nearBlackRatio, 0.60)
    }

    // MARK: Helpers

    private func averageLuminanceLeftHalf(_ image: UIImage) -> Double {
        guard let cg = image.cgImage else { return -1 }
        let side = 16
        guard let context = CGContext(
            data: nil, width: side, height: side, bitsPerComponent: 8,
            bytesPerRow: side, space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return -1 }
        context.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))
        guard let data = context.data else { return -1 }
        let pixels = data.bindMemory(to: UInt8.self, capacity: side * side)
        var sum = 0.0
        var count = 0
        for y in 0..<side {
            for x in 0..<(side / 2) {
                sum += Double(pixels[y * side + x]) / 255.0
                count += 1
            }
        }
        return sum / Double(count)
    }
}
