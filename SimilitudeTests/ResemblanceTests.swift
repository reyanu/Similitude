import XCTest
import CoreGraphics
@testable import Similitude

final class ResemblanceTests: XCTestCase {

    // MARK: Synthetic faces

    /// Builds landmark points for a parameterized symmetric synthetic face
    /// in a 400×500 bounding box. Parameters shift individual features so
    /// tests can vary one trait at a time.
    private func syntheticFace(
        eyeSpacing: CGFloat = 120,
        eyeWidth: CGFloat = 40,
        eyeHeight: CGFloat = 16,
        mouthWidth: CGFloat = 90,
        noseWidth: CGFloat = 50,
        noseAsymmetry: CGFloat = 0
    ) -> FaceLandmarkPoints {
        let box = CGRect(x: 100, y: 100, width: 400, height: 500)
        let centerX = box.midX
        let eyeY = box.minY + 320
        let leftEyeCenter = CGPoint(x: centerX - eyeSpacing / 2, y: eyeY)
        let rightEyeCenter = CGPoint(x: centerX + eyeSpacing / 2, y: eyeY)

        func eyePoints(_ c: CGPoint) -> [CGPoint] {
            [
                CGPoint(x: c.x - eyeWidth / 2, y: c.y),
                CGPoint(x: c.x, y: c.y + eyeHeight / 2),
                CGPoint(x: c.x + eyeWidth / 2, y: c.y),
                CGPoint(x: c.x, y: c.y - eyeHeight / 2),
            ]
        }

        func browPoints(_ c: CGPoint) -> [CGPoint] {
            [
                CGPoint(x: c.x - eyeWidth / 2, y: c.y + 30),
                CGPoint(x: c.x, y: c.y + 36),
                CGPoint(x: c.x + eyeWidth / 2, y: c.y + 30),
            ]
        }

        let noseCenter = CGPoint(x: centerX + noseAsymmetry, y: eyeY - 70)
        let nose = [
            CGPoint(x: noseCenter.x - noseWidth / 2, y: noseCenter.y - 30),
            CGPoint(x: noseCenter.x, y: noseCenter.y + 40),
            CGPoint(x: noseCenter.x + noseWidth / 2, y: noseCenter.y - 30),
        ]

        let mouthCenter = CGPoint(x: centerX, y: eyeY - 150)
        let outerLips = [
            CGPoint(x: mouthCenter.x - mouthWidth / 2, y: mouthCenter.y),
            CGPoint(x: mouthCenter.x, y: mouthCenter.y + 14),
            CGPoint(x: mouthCenter.x + mouthWidth / 2, y: mouthCenter.y),
            CGPoint(x: mouthCenter.x, y: mouthCenter.y - 14),
        ]
        let innerLips = outerLips.map { CGPoint(x: $0.x * 0.98, y: $0.y) }

        // Contour: ear → jaw → chin → jaw → ear (y decreases toward chin).
        let contour = [
            CGPoint(x: box.minX, y: eyeY),
            CGPoint(x: box.minX + 30, y: eyeY - 120),
            CGPoint(x: box.minX + 90, y: box.minY + 60),
            CGPoint(x: centerX, y: box.minY),
            CGPoint(x: box.maxX - 90, y: box.minY + 60),
            CGPoint(x: box.maxX - 30, y: eyeY - 120),
            CGPoint(x: box.maxX, y: eyeY),
            CGPoint(x: box.maxX, y: eyeY + 1),
        ]

        return FaceLandmarkPoints(
            boundingBox: box,
            faceContour: contour,
            leftEye: eyePoints(leftEyeCenter),
            rightEye: eyePoints(rightEyeCenter),
            leftEyebrow: browPoints(leftEyeCenter),
            rightEyebrow: browPoints(rightEyeCenter),
            nose: nose,
            outerLips: outerLips,
            innerLips: innerLips
        )
    }

    private let geometry = FaceGeometryService()
    private let scorer = ResemblanceScoringService()

    // MARK: Geometry

    func testMetricsAreComputedForCompleteFace() {
        let m = geometry.metrics(from: syntheticFace())
        XCTAssertNotNil(m.faceAspectRatio)
        XCTAssertNotNil(m.eyeSpacingRatio)
        XCTAssertNotNil(m.eyeSizeRatio)
        XCTAssertNotNil(m.eyeAspectRatio)
        XCTAssertNotNil(m.eyebrowHeightRatio)
        XCTAssertNotNil(m.noseLengthRatio)
        XCTAssertNotNil(m.noseWidthRatio)
        XCTAssertNotNil(m.mouthWidthRatio)
        XCTAssertNotNil(m.lipFullnessRatio)
        XCTAssertNotNil(m.jawTaperRatio)
        XCTAssertNotNil(m.symmetryScore)
    }

    func testMetricsAreScaleInvariant() {
        let base = syntheticFace()
        // Same face at double scale.
        let scaled = FaceLandmarkPoints(
            boundingBox: CGRect(
                x: base.boundingBox.minX * 2, y: base.boundingBox.minY * 2,
                width: base.boundingBox.width * 2, height: base.boundingBox.height * 2
            ),
            faceContour: base.faceContour.map { CGPoint(x: $0.x * 2, y: $0.y * 2) },
            leftEye: base.leftEye.map { CGPoint(x: $0.x * 2, y: $0.y * 2) },
            rightEye: base.rightEye.map { CGPoint(x: $0.x * 2, y: $0.y * 2) },
            leftEyebrow: base.leftEyebrow.map { CGPoint(x: $0.x * 2, y: $0.y * 2) },
            rightEyebrow: base.rightEyebrow.map { CGPoint(x: $0.x * 2, y: $0.y * 2) },
            nose: base.nose.map { CGPoint(x: $0.x * 2, y: $0.y * 2) },
            outerLips: base.outerLips.map { CGPoint(x: $0.x * 2, y: $0.y * 2) },
            innerLips: base.innerLips.map { CGPoint(x: $0.x * 2, y: $0.y * 2) }
        )

        let a = geometry.metrics(from: base)
        let b = geometry.metrics(from: scaled)
        XCTAssertEqual(a.eyeSpacingRatio!, b.eyeSpacingRatio!, accuracy: 0.001)
        XCTAssertEqual(a.mouthWidthRatio!, b.mouthWidthRatio!, accuracy: 0.001)
        XCTAssertEqual(a.noseWidthRatio!, b.noseWidthRatio!, accuracy: 0.001)
        XCTAssertEqual(a.jawTaperRatio!, b.jawTaperRatio!, accuracy: 0.001)
    }

    func testSymmetricFaceScoresHighSymmetry() {
        let m = geometry.metrics(from: syntheticFace())
        XCTAssertGreaterThan(m.symmetryScore!, 0.9)
    }

    func testAsymmetricNoseLowersSymmetry() {
        let symmetric = geometry.metrics(from: syntheticFace())
        let asymmetric = geometry.metrics(from: syntheticFace(noseAsymmetry: 30))
        XCTAssertLessThan(asymmetric.symmetryScore!, symmetric.symmetryScore!)
    }

    func testMissingRegionsProduceNilMetricsNotCrashes() {
        let face = syntheticFace()
        let noEyes = FaceLandmarkPoints(
            boundingBox: face.boundingBox,
            faceContour: face.faceContour,
            leftEye: [], rightEye: [],
            leftEyebrow: face.leftEyebrow, rightEyebrow: face.rightEyebrow,
            nose: face.nose, outerLips: face.outerLips, innerLips: face.innerLips
        )
        let m = geometry.metrics(from: noEyes)
        XCTAssertNil(m.eyeSpacingRatio)
        XCTAssertNil(m.mouthWidthRatio) // depends on inter-eye normalizer
        XCTAssertNil(m.symmetryScore)
        XCTAssertNotNil(m.faceAspectRatio) // bounding box still present
    }

    // MARK: Scoring

    func testIdenticalFacesScoreNearPerfect() {
        let m = geometry.metrics(from: syntheticFace())
        let result = scorer.compare(m, m)
        XCTAssertGreaterThan(result.overall, 0.99)
        XCTAssertEqual(result.traits.count, 11)
        XCTAssertFalse(result.strongestTraits.isEmpty)
    }

    func testLargerDifferenceScoresLower() {
        let child = geometry.metrics(from: syntheticFace())
        let similarParent = geometry.metrics(from: syntheticFace(mouthWidth: 96))
        let differentParent = geometry.metrics(from: syntheticFace(
            eyeSpacing: 150, eyeWidth: 30, mouthWidth: 130, noseWidth: 70
        ))

        let similar = scorer.compare(child, similarParent)
        let different = scorer.compare(child, differentParent)
        XCTAssertGreaterThan(similar.overall, different.overall)
    }

    func testSingleTraitChangeOnlyAffectsRelatedTraits() {
        let child = geometry.metrics(from: syntheticFace())
        let parent = geometry.metrics(from: syntheticFace(mouthWidth: 120))
        let result = scorer.compare(child, parent)

        let mouth = result.traits.first { $0.trait == .mouthWidth }!
        let eyeSpacing = result.traits.first { $0.trait == .eyeSpacing }!
        XCTAssertLessThan(mouth.similarity, 0.7)
        XCTAssertGreaterThan(eyeSpacing.similarity, 0.95)
    }

    func testMissingMetricsAreOmittedFromComparison() {
        var a = geometry.metrics(from: syntheticFace())
        let b = geometry.metrics(from: syntheticFace())
        a.noseWidthRatio = nil
        let result = scorer.compare(a, b)
        XCTAssertFalse(result.traits.contains { $0.trait == .noseWidth })
        XCTAssertGreaterThan(result.overall, 0.9)
    }

    func testScoresStayInValidRange() {
        let a = geometry.metrics(from: syntheticFace())
        let b = geometry.metrics(from: syntheticFace(
            eyeSpacing: 200, eyeWidth: 20, eyeHeight: 30, mouthWidth: 160, noseWidth: 90
        ))
        let result = scorer.compare(a, b)
        XCTAssertGreaterThanOrEqual(result.overall, 0)
        XCTAssertLessThanOrEqual(result.overall, 1)
        for trait in result.traits {
            XCTAssertGreaterThanOrEqual(trait.similarity, 0)
            XCTAssertLessThanOrEqual(trait.similarity, 1)
        }
    }

    // MARK: Explanations

    func testExplanationsNeverUseGeneticLanguage() {
        let explainer = TraitExplanationService()
        let banned = ["gene", "genetic", "dna", "biological", "paternity", "inherit", "proof"]

        for value in stride(from: 0.0, through: 1.0, by: 0.05) {
            for trait in ResemblanceTrait.allCases {
                let text = explainer.explanation(
                    for: TraitSimilarity(trait: trait, similarity: value),
                    parentName: "Mom"
                ).lowercased()
                for word in banned {
                    XCTAssertFalse(text.contains(word), "'\(word)' found in: \(text)")
                }
            }
            let result = ResemblanceResult(traits: [], overall: value)
            let headline = explainer.headline(for: result, parentName: "Dad").lowercased()
            for word in banned {
                XCTAssertFalse(headline.contains(word), "'\(word)' found in: \(headline)")
            }
        }
    }
}
