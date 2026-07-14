import XCTest
import ZIPFoundation
@testable import Similitude

final class AvatarModelTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("avatar-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: SHA256

    func testSHA256MatchesKnownVector() throws {
        let file = tempDir.appendingPathComponent("abc.txt")
        try Data("abc".utf8).write(to: file)
        let digest = try AvatarModelDownloadService.sha256Hex(of: file)
        XCTAssertEqual(
            digest,
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
    }

    func testSHA256OfLargeFileIsStable() throws {
        // Exceeds one 1 MB streaming chunk to exercise the chunked path.
        let file = tempDir.appendingPathComponent("large.bin")
        try Data(repeating: 0xAB, count: 3 * 1024 * 1024 + 17).write(to: file)
        let first = try AvatarModelDownloadService.sha256Hex(of: file)
        let second = try AvatarModelDownloadService.sha256Hex(of: file)
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.count, 64)
    }

    // MARK: Manifest

    func testManifestDecodesWorkflowOutput() throws {
        let json = """
        {
          "version": "1.0.0",
          "zip": "SimilitudeCartoonizationModel.zip",
          "sha256": "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
          "sizeBytes": 52428800,
          "modelDirectory": "Photo2Cartoon.mlmodelc",
          "expectedFiles": [
            "Photo2Cartoon.mlmodelc/coremldata.bin",
            "Photo2Cartoon.mlmodelc/model.espresso.net"
          ]
        }
        """
        let manifest = try JSONDecoder().decode(AvatarModelManifest.self, from: Data(json.utf8))
        XCTAssertEqual(manifest.version, "1.0.0")
        XCTAssertEqual(manifest.modelDirectory, "Photo2Cartoon.mlmodelc")
        XCTAssertEqual(manifest.expectedFiles.count, 2)
        XCTAssertEqual(manifest.sizeBytes, 52_428_800)
    }

    // MARK: Expected-file validation

    private func makeManifest(expectedFiles: [String]) -> AvatarModelManifest {
        AvatarModelManifest(
            version: "1.0.0",
            zip: "SimilitudeCartoonizationModel.zip",
            sha256: "0",
            sizeBytes: 1,
            modelDirectory: "Photo2Cartoon.mlmodelc",
            expectedFiles: expectedFiles
        )
    }

    func testMissingFilesDetectsAbsentEntries() throws {
        let service = AvatarModelDownloadService()
        let manifest = makeManifest(expectedFiles: [
            "Photo2Cartoon.mlmodelc/coremldata.bin",
            "Photo2Cartoon.mlmodelc/model.espresso.net",
        ])

        // Nothing present yet: everything missing.
        XCTAssertEqual(service.missingFiles(for: manifest, in: tempDir).count, 2)

        // Create one of the two.
        let dir = tempDir.appendingPathComponent("Photo2Cartoon.mlmodelc", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: dir.appendingPathComponent("coremldata.bin"))

        let missing = service.missingFiles(for: manifest, in: tempDir)
        XCTAssertEqual(missing, ["Photo2Cartoon.mlmodelc/model.espresso.net"])

        // Create the second: nothing missing.
        try Data("y".utf8).write(to: dir.appendingPathComponent("model.espresso.net"))
        XCTAssertTrue(service.missingFiles(for: manifest, in: tempDir).isEmpty)
    }

    // MARK: Zip extraction

    func testZipRoundTripPreservesContent() throws {
        // Build a fake model directory, zip it, extract it, verify files.
        let source = tempDir.appendingPathComponent("Photo2Cartoon.mlmodelc", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        let payload = Data((0..<10_000).map { UInt8($0 % 251) })
        try payload.write(to: source.appendingPathComponent("coremldata.bin"))

        let zipURL = tempDir.appendingPathComponent("model.zip")
        try FileManager.default.zipItem(at: source, to: zipURL)

        let extracted = tempDir.appendingPathComponent("extracted", isDirectory: true)
        try FileManager.default.createDirectory(at: extracted, withIntermediateDirectories: true)
        try FileManager.default.unzipItem(at: zipURL, to: extracted)

        let extractedPayload = try Data(
            contentsOf: extracted
                .appendingPathComponent("Photo2Cartoon.mlmodelc")
                .appendingPathComponent("coremldata.bin")
        )
        XCTAssertEqual(extractedPayload, payload)
    }

    func testChecksumMismatchIsDetectedByComparison() throws {
        let file = tempDir.appendingPathComponent("model.zip")
        try Data("not the real model".utf8).write(to: file)
        let digest = try AvatarModelDownloadService.sha256Hex(of: file)
        let manifestDigest = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        XCTAssertNotEqual(digest.caseInsensitiveCompare(manifestDigest), .orderedSame)
    }
}
