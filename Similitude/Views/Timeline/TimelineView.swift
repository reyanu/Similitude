import SwiftUI

/// Family Timeline: dated portraits with resemblance history, stored only
/// on this device. Free plan saves one entry; Premium is unlimited.
struct TimelineView: View {
    @State private var store = TimelineStore.shared
    @State private var entitlements = EntitlementsService.shared
    @State private var showAddEntry = false
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            Group {
                if store.entries.isEmpty {
                    emptyState
                } else {
                    entryList
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Timeline")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if store.canAddEntry(isPremium: entitlements.isPremium) {
                            showAddEntry = true
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        Label("Add Milestone", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddEntry) {
                AddTimelineEntryView(store: store)
            }
            .sheet(isPresented: $showPaywall) {
                PremiumUpgradeView()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            PrivacyBadge()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            Spacer()

            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 52))
                .foregroundStyle(Brand.accent)
            Text("Build Your Family Timeline")
                .font(.title2.bold())
            Text("Add dated portraits — newborn, 3 months, birthdays, school milestones — and watch resemblance evolve.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                showAddEntry = true
            } label: {
                Label("Add First Milestone", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
    }

    private var entryList: some View {
        List {
            if !entitlements.isPremium {
                Section {
                    Button {
                        showPaywall = true
                    } label: {
                        Label("Free plan saves one entry — upgrade for unlimited history", systemImage: "lock.fill")
                            .font(.footnote)
                    }
                    .tint(Brand.premiumGold)
                }
            }

            Section {
                ForEach(store.entries.reversed()) { entry in
                    TimelineEntryRow(entry: entry, store: store)
                }
                .onDelete { offsets in
                    let reversed = Array(store.entries.reversed())
                    for offset in offsets {
                        store.deleteEntry(id: reversed[offset].id)
                    }
                }
            } footer: {
                Text(Brand.entertainmentDisclaimer)
                    .font(.caption2)
            }
        }
    }
}

private struct TimelineEntryRow: View {
    let entry: TimelineEntry
    let store: TimelineStore

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let image = store.image(for: entry) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle().fill(Brand.accentSoft)
                        .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.label.isEmpty ? "Milestone" : entry.label)
                    .font(.headline)
                Text(entry.date, style: .date)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if entry.momScorePercent != nil || entry.dadScorePercent != nil {
                    HStack(spacing: 8) {
                        if let mom = entry.momScorePercent {
                            ScoreChip(label: "Mom", percent: mom)
                        }
                        if let dad = entry.dadScorePercent {
                            ScoreChip(label: "Dad", percent: dad)
                        }
                    }
                }
                if !entry.strongestTraits.isEmpty {
                    Text(entry.strongestTraits.joined(separator: " • "))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ScoreChip: View {
    let label: String
    let percent: Int

    var body: some View {
        Text("\(label) \(percent)%")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Brand.accentSoft, in: Capsule())
            .foregroundStyle(Brand.accent)
    }
}

/// Manual milestone creation: portrait through the shared face pipeline,
/// date, and label.
private struct AddTimelineEntryView: View {
    let store: TimelineStore
    @Environment(\.dismiss) private var dismiss
    @State private var entitlements = EntitlementsService.shared

    @State private var portrait: UIImage?
    @State private var status: String?
    @State private var date = Date()
    @State private var label = ""

    private let detector = FaceDetectionService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    PortraitSourcePanel(image: portrait, statusMessage: status) { image, source in
                        detect(image, source: source)
                    }

                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Milestone (e.g. First birthday)", text: $label)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        save()
                    } label: {
                        Text("Save Milestone")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(portrait == nil)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Add Milestone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func detect(_ image: UIImage, source: ImageSource) {
        Task { @MainActor in
            do {
                let face = try await Task.detached(priority: .userInitiated) { [detector] in
                    try detector.detectFace(in: image, source: source)
                }.value
                portrait = face.normalizedImage
                status = "Face detected ✓"
            } catch {
                portrait = nil
                status = error.localizedDescription
            }
        }
    }

    private func save() {
        guard let portrait else { return }
        do {
            try store.addEntry(
                image: portrait,
                date: date,
                label: label,
                isPremium: entitlements.isPremium
            )
            dismiss()
        } catch {
            status = error.localizedDescription
        }
    }
}

#Preview {
    TimelineView()
}
