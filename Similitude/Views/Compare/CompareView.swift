import SwiftUI

/// Phase 1 scope: full photo intake and face validation for Child, Mom, and
/// Dad through the shared pipeline. Resemblance scoring ships in Phase 2 and
/// is honestly labeled as coming soon until then.
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
                            // Enabled in Phase 2 when scoring lands.
                        } label: {
                            Text("Compare Faces")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(true)

                        Text("Resemblance scoring is coming soon.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
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
        }
    }
}

enum FamilyRole: String, CaseIterable, Identifiable {
    case child = "Child"
    case mom = "Mom"
    case dad = "Dad"

    var id: String { rawValue }
}

@Observable
final class CompareViewModel {
    struct Slot {
        var image: UIImage?
        var status: String?
    }

    var slots: [FamilyRole: Slot] = [:]

    private let detector = FaceDetectionService()

    func setPhoto(_ image: UIImage, source: ImageSource, for role: FamilyRole) {
        Task { @MainActor in
            do {
                let face = try await Task.detached(priority: .userInitiated) { [detector] in
                    try detector.detectFace(in: image, source: source)
                }.value
                slots[role] = Slot(image: face.normalizedImage, status: "Face detected ✓")
            } catch {
                slots[role] = Slot(image: nil, status: error.localizedDescription)
            }
        }
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
