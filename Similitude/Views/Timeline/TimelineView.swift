import SwiftUI

/// Family Timeline ships in Phase 6. The tab exists for stable navigation
/// and is honestly labeled as coming soon.
struct TimelineView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                PrivacyBadge()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                Spacer()

                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 52))
                    .foregroundStyle(Brand.accent)
                Text("Family Timeline")
                    .font(.title2.bold())
                Text("Track resemblance across months, years, and milestones. Coming soon.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Timeline")
        }
    }
}

#Preview {
    TimelineView()
}
