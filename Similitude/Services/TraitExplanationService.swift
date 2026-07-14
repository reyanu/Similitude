import Foundation

/// Turns trait similarities into warm, family-friendly explanations.
/// Language is always observational ("looks similar"), never genetic or
/// scientific ("inherited", "genes", "proof").
struct TraitExplanationService {

    func explanation(for similarity: TraitSimilarity, parentName: String) -> String {
        let trait = similarity.trait.displayName.lowercased()
        switch similarity.similarity {
        case 0.85...:
            return "Remarkably similar \(trait) to \(parentName)."
        case 0.70..<0.85:
            return "The \(trait) looks a lot like \(parentName)'s."
        case 0.55..<0.70:
            return "There's a visible similarity in \(trait) with \(parentName)."
        case 0.40..<0.55:
            return "Some resemblance to \(parentName) in \(trait)."
        default:
            return "The \(trait) looks quite distinct from \(parentName)'s."
        }
    }

    /// A short headline for the result screen.
    func headline(for result: ResemblanceResult, parentName: String) -> String {
        switch result.overall {
        case 0.75...:
            return "A striking resemblance to \(parentName)!"
        case 0.60..<0.75:
            return "Plenty of \(parentName)'s features here."
        case 0.45..<0.60:
            return "A gentle echo of \(parentName)."
        default:
            return "A look all their own — with hints of \(parentName)."
        }
    }
}
