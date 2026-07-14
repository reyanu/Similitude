import Foundation

/// The visible facial traits compared between two faces.
enum ResemblanceTrait: String, CaseIterable, Identifiable {
    case faceShape
    case eyeSpacing
    case eyeSize
    case eyeShape
    case eyebrowPosition
    case noseLength
    case noseWidth
    case mouthWidth
    case lipProportions
    case jawAndChin
    case symmetry

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .faceShape: return "Face shape"
        case .eyeSpacing: return "Eye spacing"
        case .eyeSize: return "Eye size"
        case .eyeShape: return "Eye shape"
        case .eyebrowPosition: return "Eyebrow position"
        case .noseLength: return "Nose length"
        case .noseWidth: return "Nose width"
        case .mouthWidth: return "Mouth width"
        case .lipProportions: return "Lip proportions"
        case .jawAndChin: return "Jaw & chin"
        case .symmetry: return "Facial symmetry"
        }
    }
}

/// One trait's similarity between two faces, 0…1.
struct TraitSimilarity: Identifiable {
    let trait: ResemblanceTrait
    let similarity: Double

    var id: String { trait.id }
    var percent: Int { Int((similarity * 100).rounded()) }
}

/// Full comparison result between a child and one parent.
struct ResemblanceResult {
    let traits: [TraitSimilarity]
    /// Weighted overall similarity, 0…1.
    let overall: Double

    var overallPercent: Int { Int((overall * 100).rounded()) }

    /// The clearest visible matches, strongest first.
    var strongestTraits: [TraitSimilarity] {
        traits.filter { $0.similarity >= 0.60 }
            .sorted { $0.similarity > $1.similarity }
            .prefix(3)
            .map { $0 }
    }
}

/// Compares two faces' geometric metrics trait by trait. Entirely
/// explainable: each trait similarity comes from the difference of one
/// documented ratio, never from an opaque embedding.
///
/// Results are for entertainment and keepsakes only — the scoring is
/// deliberately presented as approximate, never as scientific.
struct ResemblanceScoringService {

    /// Per-trait comparison scales: the metric difference at which
    /// similarity falls to 50%. Chosen from plausible human variation of
    /// each ratio, so scores spread usefully instead of clustering at 100%.
    private struct TraitSpec {
        let trait: ResemblanceTrait
        let keyPath: KeyPath<FaceMetrics, Double?>
        let halfScale: Double
        let weight: Double
    }

    private static let specs: [TraitSpec] = [
        TraitSpec(trait: .faceShape, keyPath: \.faceAspectRatio, halfScale: 0.10, weight: 1.2),
        TraitSpec(trait: .eyeSpacing, keyPath: \.eyeSpacingRatio, halfScale: 0.045, weight: 1.1),
        TraitSpec(trait: .eyeSize, keyPath: \.eyeSizeRatio, halfScale: 0.055, weight: 1.0),
        TraitSpec(trait: .eyeShape, keyPath: \.eyeAspectRatio, halfScale: 0.09, weight: 0.9),
        TraitSpec(trait: .eyebrowPosition, keyPath: \.eyebrowHeightRatio, halfScale: 0.055, weight: 0.8),
        TraitSpec(trait: .noseLength, keyPath: \.noseLengthRatio, halfScale: 0.045, weight: 1.0),
        TraitSpec(trait: .noseWidth, keyPath: \.noseWidthRatio, halfScale: 0.075, weight: 1.0),
        TraitSpec(trait: .mouthWidth, keyPath: \.mouthWidthRatio, halfScale: 0.10, weight: 1.0),
        TraitSpec(trait: .lipProportions, keyPath: \.lipFullnessRatio, halfScale: 0.09, weight: 0.9),
        TraitSpec(trait: .jawAndChin, keyPath: \.jawTaperRatio, halfScale: 0.09, weight: 1.1),
        TraitSpec(trait: .symmetry, keyPath: \.symmetryScore, halfScale: 0.12, weight: 0.6),
    ]

    /// Compares two faces. Traits whose metric is missing on either face
    /// are omitted rather than guessed.
    func compare(_ a: FaceMetrics, _ b: FaceMetrics) -> ResemblanceResult {
        var traits: [TraitSimilarity] = []
        var weightedSum = 0.0
        var weightTotal = 0.0

        for spec in Self.specs {
            guard let va = a[keyPath: spec.keyPath],
                  let vb = b[keyPath: spec.keyPath] else { continue }
            let difference = abs(va - vb)
            // similarity = 0.5 ^ (d / halfScale)^2 — smooth, 1 at identity,
            // 0.5 at the half scale, approaching 0 for large differences.
            let similarity = pow(0.5, pow(difference / spec.halfScale, 2))
            traits.append(TraitSimilarity(trait: spec.trait, similarity: similarity))
            weightedSum += similarity * spec.weight
            weightTotal += spec.weight
        }

        let overall = weightTotal > 0 ? weightedSum / weightTotal : 0
        return ResemblanceResult(traits: traits, overall: overall)
    }
}
