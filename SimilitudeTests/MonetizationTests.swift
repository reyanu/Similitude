import XCTest
import UIKit
@testable import Similitude

final class MonetizationTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suiteName = "MonetizationTests"

    override func setUpWithError() throws {
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    // MARK: Export limits

    func testFreshUserHasThreeFreeExports() {
        let limits = ExportLimitService(defaults: defaults)
        XCTAssertEqual(limits.remainingFreeExports(), 3)
        XCTAssertTrue(limits.canExport(isPremium: false))
    }

    func testThreeExportsExhaustFreeBudget() {
        let limits = ExportLimitService(defaults: defaults)
        limits.recordExport()
        limits.recordExport()
        XCTAssertEqual(limits.remainingFreeExports(), 1)
        limits.recordExport()
        XCTAssertEqual(limits.remainingFreeExports(), 0)
        XCTAssertFalse(limits.canExport(isPremium: false))
    }

    func testPremiumIsNeverLimited() {
        let limits = ExportLimitService(defaults: defaults)
        limits.recordExport()
        limits.recordExport()
        limits.recordExport()
        XCTAssertTrue(limits.canExport(isPremium: true))
    }

    func testRollingWindowFreesBudgetAfterSevenDays() {
        var currentTime = Date(timeIntervalSince1970: 1_700_000_000)
        let limits = ExportLimitService(defaults: defaults, now: { currentTime })

        limits.recordExport()
        limits.recordExport()
        limits.recordExport()
        XCTAssertEqual(limits.remainingFreeExports(), 0)

        // 6 days later: still exhausted.
        currentTime = currentTime.addingTimeInterval(6 * 24 * 3600)
        XCTAssertEqual(limits.remainingFreeExports(), 0)

        // 7 days + 1 second after the exports: budget restored.
        currentTime = currentTime.addingTimeInterval(1 * 24 * 3600 + 1)
        XCTAssertEqual(limits.remainingFreeExports(), 3)
    }

    func testWindowIsRollingNotCalendarReset() {
        var currentTime = Date(timeIntervalSince1970: 1_700_000_000)
        let limits = ExportLimitService(defaults: defaults, now: { currentTime })

        limits.recordExport()
        // Two more exports three days later.
        currentTime = currentTime.addingTimeInterval(3 * 24 * 3600)
        limits.recordExport()
        limits.recordExport()
        XCTAssertEqual(limits.remainingFreeExports(), 0)

        // 7 days after the FIRST export only that one expires.
        currentTime = currentTime.addingTimeInterval(4 * 24 * 3600 + 1)
        XCTAssertEqual(limits.remainingFreeExports(), 1)

        let nextDate = limits.nextFreeExportDate()
        XCTAssertNil(nextDate, "nextFreeExportDate is nil when budget remains")
    }

    func testNextFreeExportDateWhenExhausted() {
        var currentTime = Date(timeIntervalSince1970: 1_700_000_000)
        let limits = ExportLimitService(defaults: defaults, now: { currentTime })
        let firstExport = currentTime

        limits.recordExport()
        currentTime = currentTime.addingTimeInterval(60)
        limits.recordExport()
        limits.recordExport()

        let next = limits.nextFreeExportDate()
        XCTAssertEqual(
            next?.timeIntervalSince1970 ?? 0,
            firstExport.addingTimeInterval(ExportLimitService.windowSeconds).timeIntervalSince1970,
            accuracy: 1
        )
    }

    // MARK: Watermark

    private func solidImage(color: UIColor, size: CGSize = CGSize(width: 800, height: 600)) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            color.setFill()
            ctx.cgContext.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func averageLuminance(of image: UIImage, in normalizedRect: CGRect) -> Double {
        guard let cg = image.cgImage else { return -1 }
        let rect = CGRect(
            x: normalizedRect.minX * CGFloat(cg.width),
            y: normalizedRect.minY * CGFloat(cg.height),
            width: normalizedRect.width * CGFloat(cg.width),
            height: normalizedRect.height * CGFloat(cg.height)
        ).integral
        guard let cropped = cg.cropping(to: rect) else { return -1 }
        let side = 32
        guard let context = CGContext(
            data: nil, width: side, height: side, bitsPerComponent: 8,
            bytesPerRow: side, space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return -1 }
        context.draw(cropped, in: CGRect(x: 0, y: 0, width: side, height: side))
        guard let data = context.data else { return -1 }
        let pixels = data.bindMemory(to: UInt8.self, capacity: side * side)
        var sum = 0.0
        for i in 0..<(side * side) { sum += Double(pixels[i]) }
        return sum / Double(side * side) / 255.0
    }

    func testWatermarkChangesBottomRightCorner() {
        let original = solidImage(color: .darkGray)
        let watermarked = WatermarkService().applyWatermark(to: original)

        XCTAssertEqual(watermarked.size, original.size)

        // Bottom-right corner must brighten (white text on dark gray).
        let corner = CGRect(x: 0.6, y: 0.85, width: 0.4, height: 0.15)
        let before = averageLuminance(of: original, in: corner)
        let after = averageLuminance(of: watermarked, in: corner)
        XCTAssertGreaterThan(after, before + 0.01, "Watermark text must be visible in the bottom-right")

        // Top-left must be untouched.
        let topLeft = CGRect(x: 0, y: 0, width: 0.4, height: 0.4)
        XCTAssertEqual(
            averageLuminance(of: watermarked, in: topLeft),
            averageLuminance(of: original, in: topLeft),
            accuracy: 0.02
        )
    }

    // MARK: Downscale

    func testFreeExportDownscalesTo720pClass() {
        let large = solidImage(color: .red, size: CGSize(width: 3000, height: 4000))
        let prepared = ExportService().prepareForExport(large, isPremium: false)
        let maxDim = max(prepared.size.width * prepared.scale, prepared.size.height * prepared.scale)
        XCTAssertLessThanOrEqual(maxDim, ExportService.freeMaxDimension + 1)
    }

    func testPremiumExportKeepsFullResolutionAndNoWatermark() {
        let large = solidImage(color: .darkGray, size: CGSize(width: 3000, height: 4000))
        let prepared = ExportService().prepareForExport(large, isPremium: true)
        XCTAssertEqual(prepared.size, large.size)

        let corner = CGRect(x: 0.6, y: 0.85, width: 0.4, height: 0.15)
        XCTAssertEqual(
            averageLuminance(of: prepared, in: corner),
            averageLuminance(of: large, in: corner),
            accuracy: 0.02,
            "Premium exports must not be watermarked"
        )
    }

    func testDownscaleLeavesSmallImagesUntouched() {
        let small = solidImage(color: .blue, size: CGSize(width: 640, height: 480))
        let result = ExportService.downscaled(small, maxDimension: ExportService.freeMaxDimension)
        XCTAssertEqual(result.size, small.size)
    }
}
