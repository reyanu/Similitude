import XCTest
import UIKit
@testable import Similitude

final class KeepsakeTests: XCTestCase {

    private let renderer = KeepsakeTemplateRenderer()

    private func portrait(color: UIColor = .systemBrown) -> UIImage {
        let size = CGSize(width: 300, height: 300)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            color.setFill()
            ctx.cgContext.fill(CGRect(origin: .zero, size: size))
        }
    }

    // MARK: Registry

    func testRegistryContainsExactlyThreeV1Templates() {
        XCTAssertEqual(KeepsakeTemplate.all.map(\.id), ["birthday", "graduation", "familyPoster"])
    }

    func testAllPortraitFramesLieWithinCanvas() {
        let canvas = CGRect(origin: .zero, size: KeepsakeTemplate.canvasSize)
        for template in KeepsakeTemplate.all {
            for (count, frames) in template.portraitLayouts {
                XCTAssertEqual(frames.count, count, "\(template.id) layout for \(count) has \(frames.count) frames")
                for frame in frames {
                    XCTAssertTrue(canvas.contains(frame), "\(template.id): frame \(frame) escapes canvas")
                }
            }
            XCTAssertTrue(canvas.contains(template.titleFrame))
            XCTAssertTrue(canvas.contains(template.messageFrame))
        }
    }

    func testFamilyPosterSupportsTwoToFourPortraits() {
        let poster = KeepsakeTemplate.familyPoster
        XCTAssertEqual(poster.minPortraits, 2)
        XCTAssertEqual(poster.maxPortraits, 4)
        for count in 2...4 {
            XCTAssertNotNil(poster.frames(for: count))
        }
    }

    // MARK: Renderer

    func testRenderProducesCanvasSizedImage() throws {
        let image = try renderer.render(
            template: .birthday,
            portraits: [portrait()],
            title: "Happy Birthday!",
            message: "You make every day brighter!",
            watermarked: false,
            scale: 0.25
        )
        XCTAssertEqual(image.size.width, KeepsakeTemplate.canvasSize.width * 0.25, accuracy: 2)
        XCTAssertEqual(image.size.height, KeepsakeTemplate.canvasSize.height * 0.25, accuracy: 2)

        let stats = try XCTUnwrap(ImageStatistics.compute(for: image))
        XCTAssertFalse(stats.isSuspicious, "Rendered keepsake must not be blank or black")
    }

    func testPortraitIsActuallyComposited() throws {
        // Render with a saturated portrait vs a white one — the portrait
        // region must differ, proving compositing happens.
        let withDark = try renderer.render(
            template: .birthday, portraits: [portrait(color: .black)],
            title: "T", message: "M", watermarked: false, scale: 0.25
        )
        let withLight = try renderer.render(
            template: .birthday, portraits: [portrait(color: .white)],
            title: "T", message: "M", watermarked: false, scale: 0.25
        )
        let darkStats = try XCTUnwrap(ImageStatistics.compute(for: withDark))
        let lightStats = try XCTUnwrap(ImageStatistics.compute(for: withLight))
        XCTAssertGreaterThan(
            darkStats.nearBlackRatio, lightStats.nearBlackRatio,
            "Portrait pixels must appear in the composition"
        )
    }

    func testUnsupportedPortraitCountThrows() {
        XCTAssertThrowsError(try renderer.render(
            template: .birthday, portraits: [portrait(), portrait()],
            title: "T", message: "M", watermarked: false, scale: 0.2
        ))
        XCTAssertThrowsError(try renderer.render(
            template: .familyPoster, portraits: [portrait()],
            title: "T", message: "M", watermarked: false, scale: 0.2
        ))
    }

    func testFamilyPosterRendersWithEachSupportedCount() throws {
        for count in 2...4 {
            let portraits = (0..<count).map { _ in portrait() }
            let image = try renderer.render(
                template: .familyPoster, portraits: portraits,
                title: "Family", message: "Together", watermarked: false, scale: 0.2
            )
            let stats = try XCTUnwrap(ImageStatistics.compute(for: image))
            XCTAssertFalse(stats.isSuspicious)
        }
    }

    func testFullExportScaleRendersAtSpecResolution() throws {
        let image = try renderer.render(
            template: .graduation, portraits: [portrait()],
            title: KeepsakeTemplate.graduation.defaultTitle,
            message: KeepsakeTemplate.graduation.defaultMessage,
            watermarked: false, scale: 1.0
        )
        XCTAssertEqual(image.size.width, 1600, accuracy: 2)
        XCTAssertEqual(image.size.height, 2000, accuracy: 2)
    }

    func testMaskImagesAreGenerated() throws {
        let circle = KeepsakeTemplateRenderer.maskImage(
            for: .circle(featherFraction: 0.05), size: CGSize(width: 200, height: 200)
        )
        let rounded = KeepsakeTemplateRenderer.maskImage(
            for: .roundedRect(cornerFraction: 0.1, featherFraction: 0.05), size: CGSize(width: 200, height: 200)
        )
        for mask in [try XCTUnwrap(circle), try XCTUnwrap(rounded)] {
            let stats = try XCTUnwrap(ImageStatistics.compute(for: mask))
            // A useful mask has both visible (white) and hidden (black) regions.
            XCTAssertGreaterThan(stats.nearWhiteRatio, 0.2)
            XCTAssertGreaterThan(stats.nearBlackRatio, 0.05)
        }
    }

    func testFallbackArtworkIsNotBlank() throws {
        for template in KeepsakeTemplate.all {
            let background = TemplateArtworkFallback.background(
                for: template.id, size: CGSize(width: 400, height: 500)
            )
            let stats = try XCTUnwrap(ImageStatistics.compute(for: background))
            XCTAssertGreaterThan(stats.luminanceVariance, 0.0005, "\(template.id) background too flat")
            XCTAssertLessThan(stats.nearBlackRatio, 0.5)
        }
    }

    func testWatermarkOnlyWhenRequested() throws {
        let clean = try renderer.render(
            template: .birthday, portraits: [portrait()],
            title: "T", message: "M", watermarked: false, scale: 0.3
        )
        let marked = try renderer.render(
            template: .birthday, portraits: [portrait()],
            title: "T", message: "M", watermarked: true, scale: 0.3
        )
        XCTAssertEqual(clean.size, marked.size)
        // Deterministic renders: any difference comes from the watermark.
        XCTAssertNotEqual(clean.pngData(), marked.pngData())
    }
}
