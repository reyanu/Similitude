import XCTest
import UIKit
@testable import Similitude

@MainActor
final class TimelineTests: XCTestCase {

    private var directory: URL!

    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("timeline-tests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func portrait() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.systemTeal.setFill()
            ctx.cgContext.fill(CGRect(origin: .zero, size: size))
        }
    }

    func testAddPersistAndReloadEntry() throws {
        let store = TimelineStore(directory: directory)
        let entry = try store.addEntry(
            image: portrait(),
            date: Date(timeIntervalSince1970: 1_600_000_000),
            label: "First birthday",
            momScorePercent: 72,
            dadScorePercent: 65,
            strongestTraits: ["Eye spacing", "Mouth width"],
            isPremium: true
        )
        XCTAssertEqual(store.entries.count, 1)
        XCTAssertNotNil(store.image(for: entry))

        // A fresh store from the same directory reloads everything.
        let reloaded = TimelineStore(directory: directory)
        XCTAssertEqual(reloaded.entries, [entry])
        XCTAssertNotNil(reloaded.image(for: entry))
    }

    func testFreeLimitIsOneEntry() throws {
        let store = TimelineStore(directory: directory)
        XCTAssertTrue(store.canAddEntry(isPremium: false))
        try store.addEntry(image: portrait(), date: Date(), label: "Newborn", isPremium: false)
        XCTAssertFalse(store.canAddEntry(isPremium: false))

        XCTAssertThrowsError(
            try store.addEntry(image: portrait(), date: Date(), label: "3 months", isPremium: false)
        ) { error in
            guard case TimelineError.freeLimitReached = error else {
                return XCTFail("Expected freeLimitReached, got \(error)")
            }
        }
    }

    func testPremiumIsUnlimited() throws {
        let store = TimelineStore(directory: directory)
        for i in 0..<5 {
            try store.addEntry(image: portrait(), date: Date(), label: "Milestone \(i)", isPremium: true)
        }
        XCTAssertEqual(store.entries.count, 5)
        XCTAssertTrue(store.canAddEntry(isPremium: true))
    }

    func testEntriesAreSortedByDate() throws {
        let store = TimelineStore(directory: directory)
        let later = Date(timeIntervalSince1970: 1_700_000_000)
        let earlier = Date(timeIntervalSince1970: 1_600_000_000)
        try store.addEntry(image: portrait(), date: later, label: "Later", isPremium: true)
        try store.addEntry(image: portrait(), date: earlier, label: "Earlier", isPremium: true)
        XCTAssertEqual(store.entries.map(\.label), ["Earlier", "Later"])
    }

    func testDeleteRemovesEntryAndImageFile() throws {
        let store = TimelineStore(directory: directory)
        let entry = try store.addEntry(image: portrait(), date: Date(), label: "Newborn", isPremium: true)
        let imagePath = directory.appendingPathComponent(entry.imageFileName).path
        XCTAssertTrue(FileManager.default.fileExists(atPath: imagePath))

        store.deleteEntry(id: entry.id)
        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: imagePath))

        // Deletion frees the single free slot again.
        XCTAssertTrue(store.canAddEntry(isPremium: false))
    }
}
