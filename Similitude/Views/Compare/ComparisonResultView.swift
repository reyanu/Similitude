import SwiftUI
import UIKit

/// Resemblance results: child centered between parents, relative shares
/// that total 100% when both parents are present, strongest matches shown
/// only for the closer parent, share card, and Save to Timeline.
struct ComparisonResultView: View {
    let comparison: FamilyComparison
    @Environment(\.dismiss) private var dismiss
    @State private var entitlements = EntitlementsService.shared
    @State private var showPaywall = false
    @State private var timelineMessage: String?
    @State private var shareImage: UIImage?
    @State private var showShareSheet = false

    private let explainer = TraitExplanationService()

    /// Free plan shows the overall score plus this many traits per parent.
    private static let freeTraitCount = 3

    /// A parent with its displayed (relative) share of the resemblance.
    private struct ParentDisplay: Identifiable {
        let outcome: FamilyComparison.ParentOutcome
        let sharePercent: Int
        let isPrimary: Bool
        var id: String { outcome.id }
    }

    /// With both parents, shares total 100%: the closer parent keeps the
    /// larger of (their score, 100 − their score), the other gets the rest.
    /// With one parent, the raw score is shown.
    private var displays: [ParentDisplay] {
        let parents = comparison.parents
        guard parents.count == 2 else {
            return parents.map {
                ParentDisplay(outcome: $0, sharePercent: $0.result.overallPercent, isPrimary: true)
            }
        }
        let winnerIndex = parents[0].result.overall >= parents[1].result.overall ? 0 : 1
        let winner = parents[winnerIndex]
        let winnerShare = max(winner.result.overallPercent, 100 - winner.result.overallPercent)
        return parents.enumerated().map { index, parent in
            ParentDisplay(
                outcome: parent,
                sharePercent: index == winnerIndex ? winnerShare : 100 - winnerShare,
                isPrimary: index == winnerIndex
            )
        }
    }

    private var primary: ParentDisplay? {
        displays.first { $0.isPrimary }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    scoreRow

                    if displays.count == 2 {
                        Text("Relative resemblance — the two shares total 100%.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    if let primary {
                        strongestMatchesCard(for: primary)
                    }

                    ForEach(displays) { display in
                        traitCard(for: display)
                    }

                    actionButtons

                    Text(Brand.entertainmentDisclaimer)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .brandBackground()
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
            .sheet(isPresented: $showShareSheet) {
                if let shareImage {
                    ActivityShareSheet(items: [shareImage])
                }
            }
        }
    }

    // MARK: Score row — child centered between parents

    private var scoreRow: some View {
        HStack(alignment: .top, spacing: 10) {
            if let first = displays.first {
                ParentScoreCard(
                    title: first.outcome.role.rawValue,
                    image: first.outcome.image,
                    percent: first.sharePercent,
                    isPrimary: first.isPrimary
                )
            }

            VStack(spacing: 8) {
                Image(uiImage: comparison.childImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 108, height: 108)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                Text("Child")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical)

            if displays.count == 2 {
                ParentScoreCard(
                    title: displays[1].outcome.role.rawValue,
                    image: displays[1].outcome.image,
                    percent: displays[1].sharePercent,
                    isPrimary: displays[1].isPrimary
                )
            }
        }
    }

    private func strongestMatchesCard(for display: ParentDisplay) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(explainer.headline(for: display.outcome.result, parentName: display.outcome.role.rawValue))
                .font(.headline)
                .foregroundStyle(.white)

            if !display.outcome.result.strongestTraits.isEmpty {
                Text("Strongest matches")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Brand.premiumGold)
                ForEach(display.outcome.result.strongestTraits) { trait in
                    Label(
                        explainer.explanation(for: trait, parentName: display.outcome.role.rawValue),
                        systemImage: "sparkles"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.cardBackground, in: RoundedRectangle(cornerRadius: Brand.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Brand.cardCornerRadius)
                .strokeBorder(Brand.premiumGold.opacity(0.5), lineWidth: 1)
        )
    }

    private func traitCard(for display: ParentDisplay) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(display.outcome.role.rawValue) — feature by feature")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Brand.lightBlue)

            let visibleTraits = entitlements.isPremium
                ? display.outcome.result.traits
                : Array(display.outcome.result.traits.prefix(Self.freeTraitCount))
            ForEach(visibleTraits) { trait in
                TraitRow(trait: trait)
            }

            if !entitlements.isPremium,
               display.outcome.result.traits.count > Self.freeTraitCount {
                Button {
                    showPaywall = true
                } label: {
                    Label(
                        "Unlock all \(display.outcome.result.traits.count) trait comparisons with Premium",
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

    private var actionButtons: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Button {
                    makeShareCard()
                } label: {
                    Label("Share Card", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    saveToTimeline()
                } label: {
                    Label("Save to Timeline", systemImage: "calendar.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            if let timelineMessage {
                Text(timelineMessage)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    // MARK: Actions

    private func makeShareCard() {
        guard let primary else { return }
        let entries = displays.map {
            ResemblanceShareCardRenderer.ParentEntry(
                name: $0.outcome.role.rawValue,
                image: $0.outcome.image,
                sharePercent: $0.sharePercent,
                isPrimary: $0.isPrimary
            )
        }
        let headline = explainer.headline(
            for: primary.outcome.result,
            parentName: primary.outcome.role.rawValue
        )
        shareImage = ResemblanceShareCardRenderer().render(
            childImage: comparison.childImage,
            parents: entries,
            headline: headline
        )
        showShareSheet = true
    }

    /// Captures this comparison as a timeline milestone with the displayed
    /// relative shares and the closer parent's strongest traits.
    private func saveToTimeline() {
        let mom = displays.first { $0.outcome.role == .mom }
        let dad = displays.first { $0.outcome.role == .dad }
        let traits = primary?.outcome.result.strongestTraits.map(\.trait.displayName) ?? []
        do {
            try TimelineStore.shared.addEntry(
                image: comparison.childImage,
                date: Date(),
                label: "Resemblance check",
                momScorePercent: mom?.sharePercent,
                dadScorePercent: dad?.sharePercent,
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

// MARK: - Components

private struct ParentScoreCard: View {
    let title: String
    let image: UIImage
    let percent: Int
    let isPrimary: Bool

    private var ringColor: Color {
        isPrimary ? Brand.premiumGold : Brand.lightBlue
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 84, height: 84)
                    .clipShape(Circle())
                Circle()
                    .trim(from: 0, to: CGFloat(percent) / 100)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 94, height: 94)
            }
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
            Text("\(percent)%")
                .font(.title3.bold())
                .foregroundStyle(ringColor)
            if isPrimary {
                Label("Closest", systemImage: "star.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Brand.premiumGold)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .background(Brand.cardBackground, in: RoundedRectangle(cornerRadius: Brand.cardCornerRadius))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) resemblance \(percent) percent\(isPrimary ? ", closest match" : "")")
    }
}

private struct TraitRow: View {
    let trait: TraitSimilarity

    var body: some View {
        HStack {
            Text(trait.trait.displayName)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
            Spacer()
            ProgressView(value: trait.similarity)
                .frame(width: 110)
                .tint(Brand.lightBlue)
            Text("\(trait.percent)%")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 44, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(trait.trait.displayName): \(trait.percent) percent similar")
    }
}

/// UIKit share sheet wrapper.
struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
