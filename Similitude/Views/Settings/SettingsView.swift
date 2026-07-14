import SwiftUI

struct SettingsView: View {
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
                        PlanBadge(kind: .free)
                    }
                    Text("Premium — AI Cartoon Portrait, unlimited family members, high-resolution exports, and keepsake templates — arrives in an upcoming update.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
                }
                #endif
            }
            .navigationTitle("Profile")
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
