import SwiftUI
import Vision

/// Compare: photo intake for Child, Mom, and Dad through the shared
/// pipeline, then explainable geometry-based resemblance results.
struct CompareView: View {
    @State private var model = CompareViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    PrivacyBadge()
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(FamilyRole.allCases) { role in
                        FaceSlotCard(role: role, model: model)
                    }

                    VStack(spacing: 8) {
                        Button {
                            model.compare()
                        } label: {
                            Text("Compare Faces")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(!model.canCompare)

                        if !model.canCompare {
                            Text("Add the child and at least one parent to compare.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(Brand.entertainmentDisclaimer)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Compare")
            .sheet(isPresented: $model.showResults) {
                if let comparison = model.comparison {
                    ComparisonResultView(comparison: comparison)
                }
            }
        }
    }
}

enum FamilyRole: String, CaseIterable, Identifiable {
    case child = "Child"
    case mom = "Mom"
    case dad = "Dad"

    var id: String { rawValue }
}

/// The full outcome of one comparison: child vs each provided parent.
struct FamilyComparison {
    struct ParentOutcome: Identifiable {
        let role: FamilyRole
        let image: UIImage
        let result: ResemblanceResult

        var id: String { role.id }
    }

    let childImage: UIImage
    let parents: [ParentOutcome]
}

@Observable
final class CompareViewModel {
    struct Slot {
        var face: DetectedFace?
        var status: String?

        var image: UIImage? { face?.normalizedImage }
    }

    var slots: [FamilyRole: Slot] = [:]
    var comparison: FamilyComparison?
    var showResults = false

    private let detector = FaceDetectionService()
    private let geometry = FaceGeometryService()
    private let scorer = ResemblanceScoringService()

    var canCompare: Bool {
        slots[.child]?.face != nil &&
        (slots[.mom]?.face != nil || slots[.dad]?.face != nil)
    }

    func setPhoto(_ image: UIImage, source: ImageSource, for role: FamilyRole) {
        Task { @MainActor in
            do {
                let face = try await Task.detached(priority: .userInitiated) { [detector] in
                    try detector.detectFace(in: image, source: source)
                }.value
                slots[role] = Slot(face: face, status: "Face detected ✓")
            } catch {
                slots[role] = Slot(face: nil, status: error.localizedDescription)
            }
        }
    }

    func compare() {
        guard let child = slots[.child]?.face,
              let childMetrics = metrics(for: child) else { return }

        var parents: [FamilyComparison.ParentOutcome] = []
        for role in [FamilyRole.mom, .dad] {
            guard let parent = slots[role]?.face,
                  let parentMetrics = metrics(for: parent) else { continue }
            parents.append(FamilyComparison.ParentOutcome(
                role: role,
                image: parent.normalizedImage,
                result: scorer.compare(childMetrics, parentMetrics)
            ))
        }

        guard !parents.isEmpty else { return }
        comparison = FamilyComparison(childImage: child.normalizedImage, parents: parents)
        showResults = true
    }

    private func metrics(for face: DetectedFace) -> FaceMetrics? {
        let size = face.normalizedImage.size
        guard let points = FaceLandmarkPoints.from(face.observation, imageSize: size) else {
            return nil
        }
        return geometry.metrics(from: points)
    }
}

private struct FaceSlotCard: View {
    let role: FamilyRole
    let model: CompareViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(role.rawValue)
                .font(.headline)
            PortraitSourcePanel(
                image: model.slots[role]?.image,
                statusMessage: model.slots[role]?.status
            ) { image, source in
                model.setPhoto(image, source: source, for: role)
            }
        }
        .padding()
        .background(Brand.cardBackground, in: RoundedRectangle(cornerRadius: Brand.cardCornerRadius))
    }
}

#Preview {
    CompareView()
}
