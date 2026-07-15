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
                        systemImage: "person.2.fill"
                    ) { selection = .compare }
                    ExperienceCard(
                        title: "Similitude Studio",
                        description: "Apply artistic styles or create a premium AI cartoon portrait privately on your device.",
                        cta: "Create a Portrait",
                        systemImage: "paintbrush.pointed.fill"
                    ) { selection = .studio }
                    ExperienceCard(
                        title: "Family Timeline",
                        description: "See how resemblance changes across months, years, and milestones.",
                        cta: "Build Your Family Timeline",
                        systemImage: "calendar"
                    ) { selection = .timeline }
                    ExperienceCard(
                        title: "Keepsake Studio",
                        description: "Turn family portraits into birthday cards, graduation cards, and family posters. Start from any portrait you create in the Studio.",
                        cta: "Create a Keepsake",
                        systemImage: "gift.fill"
                    ) { selection = .studio }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Similitude")
        }
    }
}

private struct ExperienceCard: View {
    let title: String
    let description: String
    let cta: String
    let systemImage: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            cardContent
        }
        .buttonStyle(.plain)
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(Brand.accent)
                    .frame(width: 34, height: 34)
                    .background(Brand.accentSoft, in: RoundedRectangle(cornerRadius: 10))
                Text(title)
                    .font(.headline)
            }

            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(cta)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Brand.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Brand.cardBackground, in: RoundedRectangle(cornerRadius: Brand.cardCornerRadius))
        .accessibilityElement(children: .combine)
        .accessibilityHint(cta)
    }
}

#Preview {
    HomeView(selection: .constant(.home))
}
