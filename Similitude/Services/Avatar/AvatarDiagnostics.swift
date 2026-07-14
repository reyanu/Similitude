import Foundation

/// Step-by-step record of the model pipeline, shown on the developer
/// diagnostics screen so failures are diagnosable without a debugger.
struct AvatarDiagnostics: Codable {
    enum Step: String, Codable, CaseIterable {
        case manifestConfigured
        case manifestFetched
        case zipDownloaded
        case checksumVerified
        case filesValidated
        case modelLoaded
        case inferenceCompleted

        var displayName: String {
            switch self {
            case .manifestConfigured: return "Model URL configured"
            case .manifestFetched: return "Manifest fetched"
            case .zipDownloaded: return "Model ZIP downloaded"
            case .checksumVerified: return "Checksum verified"
            case .filesValidated: return "Expected model files present"
            case .modelLoaded: return "Model loaded"
            case .inferenceCompleted: return "Inference completed"
            }
        }
    }

    var completedSteps: Set<Step> = []
    var lastError: String?
    var installedVersion: String?
    var installedSizeBytes: Int64?
    var lastInferenceSeconds: Double?

    mutating func complete(_ step: Step) {
        completedSteps.insert(step)
    }

    mutating func fail(_ step: Step, error: Error) {
        completedSteps.remove(step)
        lastError = "\(step.displayName): \(error.localizedDescription)"
    }

    // MARK: Persistence

    private static let defaultsKey = "avatar.diagnostics"

    static func load() -> AvatarDiagnostics {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let value = try? JSONDecoder().decode(AvatarDiagnostics.self, from: data) else {
            return AvatarDiagnostics()
        }
        return value
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }
}
