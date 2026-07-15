import SwiftUI

/// Resemblance results: overall score per parent, feature-by-feature
/// comparison, strongest matching traits, and the entertainment disclaimer.
struct ComparisonResultView: View {
    let comparison: FamilyComparison
    @Environment(\.dismiss) private var dismiss
    @State private var entitlements = EntitlementsService.shared
    @State private var showPaywall = false
    @State private var timelineMessage: String?

    private let explainer = TraitExplanationService()

    /// Free plan shows the overall score plus this many traits per parent.
    private static let freeTraitCount = 3

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Overall scores.
                    HStack(spacing: 14) {
                        ForEach(comparison.parents) { parent in
                            ScoreCard(
                                title: parent.role.rawValue,
                                image: parent.image,
                                percent: parent.result.overallPercent
                            )
                        }
                    }

                    ForEach(comparison.parents) { parent in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(explainer.headline(for: parent.result, parentName: parent.role.rawValue))
                                .font(.headline)

                            if !parent.result.strongestTraits.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Strongest matches")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Brand.accent)
                                    ForEach(parent.result.strongestTraits) { trait in
                                        Label(
                                            explainer.explanation(for: trait, parentName: parent.role.rawValue),
                                            systemImage: "sparkles"
                                        )
                                        .font(.subheadline)
                                    }
                                }
                            }

                            Divider()

                            Text("Feature by feature")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)

                            let visibleTraits = entitlements.isPremium
                                ? parent.result.traits
                                : Array(parent.result.traits.prefix(Self.freeTraitCount))
                            ForEach(visibleTraits) { trait in
                                TraitRow(trait: trait)
                            }

                            if !entitlements.isPremium,
                               parent.result.traits.count > Self.freeTraitCount {
                                Button {
                                    showPaywall = true
                                } label: {
                                    Label(
                                        "Unlock all \(parent.result.traits.count) trait comparisons with Premium",
                                        systemImage: "lock.fill"
                                    )
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .tint(Brand.premiumGold)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Brand.cardBackground, in: RoundedRectangle(cornerRadius: Brand.cardCornerRadius))
                    }

                    VStack(spacing: 6) {
                        Button {
                            saveToTimeline()
                        } label: {
                            Label("Save to Timeline", systemImage: "calendar.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)

                        if let timelineMessage {
                            Text(timelineMessage)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(Brand.entertainmentDisclaimer)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Resemblance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PremiumUpgradeView()
            }
        }
    }

    /// Captures this comparison as a timeline milestone: child portrait,
    /// today's date, both parents' scores, and the strongest traits.
    private func saveToTimeline() {
        let mom = comparison.parents.first { $0.role == .mom }
        let dad = comparison.parents.first { $0.role == .dad }
        let traits = (mom ?? dad)?.result.strongestTraits.map(\.trait.displayName) ?? []
        do {
            try TimelineStore.shared.addEntry(
                image: comparison.childImage,
                date: Date(),
                label: "Resemblance check",
                momScorePercent: mom?.result.overallPercent,
                dadScorePercent: dad?.result.overallPercent,
                strongestTraits: traits,
                isPremium: entitlements.isPremium
            )
            timelineMessage = "Saved to your Family Timeline."
        } catch TimelineError.freeLimitReached {
            showPaywall = true
        } catch {
            timelineMessage = error.localizedDescription
        }
    }
}

private struct ScoreCard: View {
    let title: String
    let image: UIImage
    let percent: Int

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 88, height: 88)
                    .clipShape(Circle())
                Circle()
                    .trim(from: 0, to: CGFloat(percent) / 100)
                    .stroke(Brand.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 98, height: 98)
            }
            Text(title)
                .font(.subheadline.weight(.medium))
            Text("\(percent)%")
                .font(.title3.bold())
                .foregroundStyle(Brand.accent)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Brand.cardBackground, in: RoundedRectangle(cornerRadius: Brand.cardCornerRadius))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) resemblance \(percent) percent")
    }
}

private struct TraitRow: View {
    let trait: TraitSimilarity

    var body: some View {
        HStack {
            Text(trait.trait.displayName)
                .font(.subheadline)
            Spacer()
            ProgressView(value: trait.similarity)
                .frame(width: 110)
                .tint(Brand.accent)
            Text("\(trait.percent)%")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(trait.trait.displayName): \(trait.percent) percent similar")
    }
}
