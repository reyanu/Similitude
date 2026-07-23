import SwiftUI

struct HomeView: View {
    @Binding var selection: AppTab

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    PrivacyBadge()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)

                    ExperienceCard(
                        title: "Family Resemblance",
                        description: "Discover visible similarities between children, parents, and siblings.",
                        cta: "Compare Family Faces",
                        illustration: { AnyView(FamilyIllustration()) }
                    ) { selection = .compare }
                    ExperienceCard(
                        title: "Similitude Studio",
                        description: "Apply artistic styles or create a premium AI cartoon portrait privately on your device.",
                        cta: "Create a Portrait",
                        illustration: { AnyView(StudioIllustration()) }
                    ) { selection = .studio }
                    ExperienceCard(
                        title: "Family Timeline",
                        description: "See how resemblance changes across months, years, and milestones.",
                        cta: "Build Your Family Timeline",
                        illustration: { AnyView(TimelineIllustration()) }
                    ) { selection = .timeline }
                    ExperienceCard(
                        title: "Keepsake Studio",
                        description: "Turn family portraits into birthday cards, graduation cards, and family posters. Start from any portrait you create in the Studio.",
                        cta: "Create a Keepsake",
                        illustration: { AnyView(KeepsakeIllustration()) }
                    ) { selection = .studio }
                }
                .padding()
            }
            .brandBackground()
            .navigationTitle("Similitude")
        }
    }
}

private struct ExperienceCard: View {
    let title: String
    let description: String
    let cta: String
    let illustration: () -> AnyView
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            cardContent
        }
        .buttonStyle(.plain)
    }

    private var cardContent: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)

                Text(cta)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Brand.lightBlue)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            illustration()
                .frame(width: 96, height: 86)
        }
        .padding()
        .background(Brand.cardBackground, in: RoundedRectangle(cornerRadius: Brand.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Brand.cardCornerRadius)
                .strokeBorder(Brand.accent.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityHint(cta)
    }
}

#Preview {
    HomeView(selection: .constant(.home))
        .preferredColorScheme(.dark)
}
