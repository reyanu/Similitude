import SwiftUI

/// Developer diagnostics for the AI model pipeline: per-step status, sizes,
/// timings, last error, and a manifest URL override for testing release
/// candidates without shipping a new build.
struct AvatarDiagnosticsView: View {
    @State private var coordinator = AvatarGenerationCoordinator()
    @State private var overrideURLText: String = UserDefaults.standard
        .string(forKey: AvatarModelConfiguration.overrideDefaultsKey) ?? ""
    @State private var githubTokenText: String = UserDefaults.standard
        .string(forKey: AvatarModelConfiguration.githubTokenKey) ?? ""

    var body: some View {
        List {
            Section("Pipeline") {
                ForEach(AvatarDiagnostics.Step.allCases, id: \.rawValue) { step in
                    HStack {
                        Text(step.displayName)
                        Spacer()
                        if coordinator.diagnostics.completedSteps.contains(step) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Image(systemName: "circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Details") {
                LabeledContent("Manifest URL",
                               value: AvatarModelConfiguration.manifestURL?.absoluteString ?? "not configured")
                LabeledContent("Installed version",
                               value: coordinator.installedVersion ?? "—")
                LabeledContent("Installed size", value: installedSizeText)
                LabeledContent("Last inference", value: inferenceTimeText)
                if let error = coordinator.diagnostics.lastError {
                    LabeledContent("Last error") {
                        Text(error)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }

            Section {
                SecureField("github_pat_…", text: $githubTokenText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Apply Token") {
                    UserDefaults.standard.set(
                        githubTokenText.isEmpty ? nil : githubTokenText,
                        forKey: AvatarModelConfiguration.githubTokenKey
                    )
                }
            } header: {
                Text("GitHub access token (private repo testing)")
            } footer: {
                Text("Fine-grained token with read-only Contents access to \(AvatarModelConfiguration.githubRepository). Lets test builds download the model while the repo is private. Remove before any public release.")
            }

            Section("Manifest URL override") {
                TextField("https://…/model-manifest.json", text: $overrideURLText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                Button("Apply Override") {
                    UserDefaults.standard.set(
                        overrideURLText.isEmpty ? nil : overrideURLText,
                        forKey: AvatarModelConfiguration.overrideDefaultsKey
                    )
                }
            }

            Section {
                Button("Download / Reinstall Model") {
                    coordinator.removeModel()
                    coordinator.downloadAndInstall()
                }
                Button("Remove Installed Model", role: .destructive) {
                    coordinator.removeModel()
                }
            }
        }
        .navigationTitle("AI Model Diagnostics")
    }

    private var installedSizeText: String {
        guard let bytes = coordinator.diagnostics.installedSizeBytes else { return "—" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private var inferenceTimeText: String {
        guard let seconds = coordinator.diagnostics.lastInferenceSeconds else { return "—" }
        return String(format: "%.2f s", seconds)
    }
}
