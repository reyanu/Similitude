import SwiftUI

struct SettingsView: View {
    @State private var entitlements = EntitlementsService.shared
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label {
                        Text(Brand.privacyMessage)
                            .font(.subheadline)
                    } icon: {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(Brand.accent)
                    }
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("All photo analysis happens on this iPhone. Nothing is uploaded to any server, cloud AI service, or analytics provider.")
                }

                Section("Plan") {
                    HStack {
                        Text("Current plan")
                        Spacer()
                        PlanBadge(kind: entitlements.isPremium ? .premium : .free)
                    }
                    if !entitlements.isPremium {
                        Button("Upgrade to Premium") {
                            showPaywall = true
                        }
                        Text("Free plan: three watermarked 720p exports per week, basic resemblance comparison.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                            .foregroundStyle(.secondary)
                    }
                    Text(Brand.entertainmentDisclaimer)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                #if DEBUG
                Section("Developer") {
                    NavigationLink("Filter Diagnostics") {
                        FilterDiagnosticsView()
                    }
                    NavigationLink("AI Model Diagnostics") {
                        AvatarDiagnosticsView()
                    }
                    Toggle("Premium override (DEBUG)", isOn: Binding(
                        get: { entitlements.debugPremiumOverride },
                        set: { entitlements.debugPremiumOverride = $0 }
                    ))
                }
                #endif
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showPaywall) {
                PremiumUpgradeView()
            }
        }
    }
}

#if DEBUG
/// Development-only view of the Pencil Sketch pipeline's intermediate stages.
struct FilterDiagnosticsView: View {
    var body: some View {
        List {
            stage("Normalized input", PencilSketchFilter.lastIntermediates.normalizedInput)
            stage("Grayscale", PencilSketchFilter.lastIntermediates.grayscale)
            stage("Edge map", PencilSketchFilter.lastIntermediates.edgeMap)
            stage("Inverted edge map", PencilSketchFilter.lastIntermediates.invertedEdgeMap)
            stage("Blended", PencilSketchFilter.lastIntermediates.blended)
            stage("Final", PencilSketchFilter.lastIntermediates.final)
        }
        .navigationTitle("Pencil Sketch Stages")
    }

    @ViewBuilder
    private func stage(_ title: String, _ image: UIImage?) -> some View {
        Section(title) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Text("Not captured yet — run the Pencil Sketch filter first.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
#endif

#Preview {
    SettingsView()
}
