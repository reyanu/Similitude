import UIKit
import Observation

/// Orchestrates the AI Cartoon Portrait pipeline and exposes UI state:
/// installation status, download progress, generation, and diagnostics.
@Observable
@MainActor
final class AvatarGenerationCoordinator {

    enum State: Equatable {
        case notInstalled
        case downloading(progress: Double)
        case installed
        case generating
        case failed(message: String)
    }

    private(set) var state: State = .notInstalled
    private(set) var diagnostics = AvatarDiagnostics.load()
    private(set) var lastResult: UIImage?

    private let downloadService = AvatarModelDownloadService()
    private var cartoonizer: PortraitCartoonizationService?

    init() {
        refreshInstalledState()
    }

    func refreshInstalledState() {
        state = downloadService.installedModelDirectory() != nil ? .installed : .notInstalled
    }

    var installedVersion: String? {
        downloadService.installedManifest()?.version
    }

    // MARK: Install

    func downloadAndInstall() {
        guard state == .notInstalled || isFailed else { return }
        state = .downloading(progress: 0)

        Task {
            var diag = diagnostics
            do {
                let service = downloadService
                _ = try await service.install(diagnostics: &diag) { fraction in
                    Task { @MainActor [weak self] in
                        if case .downloading = self?.state {
                            self?.state = .downloading(progress: fraction)
                        }
                    }
                }
                diagnostics = diag
                diagnostics.save()
                state = .installed
            } catch {
                diagnostics = diag
                diagnostics.save()
                state = .failed(message: error.localizedDescription)
            }
        }
    }

    func removeModel() {
        try? downloadService.removeInstalledModel()
        cartoonizer = nil
        refreshInstalledState()
    }

    // MARK: Generate

    func generate(from image: UIImage) {
        guard state == .installed else { return }
        state = .generating

        Task {
            var diag = diagnostics
            do {
                let service = try loadedCartoonizer(diagnostics: &diag)
                let (result, seconds) = try await Task.detached(priority: .userInitiated) {
                    try service.cartoonize(image)
                }.value
                diag.complete(.inferenceCompleted)
                diag.lastInferenceSeconds = seconds
                diagnostics = diag
                diagnostics.save()
                lastResult = result
                state = .installed
            } catch {
                diag.fail(.inferenceCompleted, error: error)
                diagnostics = diag
                diagnostics.save()
                state = .failed(message: error.localizedDescription)
            }
        }
    }

    func clearResult() {
        lastResult = nil
    }

    func acknowledgeFailure() {
        refreshInstalledState()
    }

    // MARK: Helpers

    private var isFailed: Bool {
        if case .failed = state { return true }
        return false
    }

    private func loadedCartoonizer(diagnostics: inout AvatarDiagnostics) throws -> PortraitCartoonizationService {
        if let cartoonizer { return cartoonizer }
        guard let modelDir = downloadService.installedModelDirectory() else {
            throw CartoonizationError.modelLoadFailed("model is not installed")
        }
        do {
            let service = try PortraitCartoonizationService(modelDirectoryURL: modelDir)
            diagnostics.complete(.modelLoaded)
            cartoonizer = service
            return service
        } catch {
            diagnostics.fail(.modelLoaded, error: error)
            throw error
        }
    }
}
