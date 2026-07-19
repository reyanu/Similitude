import Foundation
import CryptoKit
import ZIPFoundation

enum AvatarModelError: LocalizedError {
    case notConfigured
    case manifestInvalid
    case downloadFailed(String)
    case checksumMismatch
    case expectedFilesMissing([String])
    case installationFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "AI model source is not configured."
        case .manifestInvalid:
            return "The model manifest could not be read."
        case .downloadFailed(let reason):
            return "Model download failed: \(reason)"
        case .checksumMismatch:
            return "Model verification failed. Please try downloading again."
        case .expectedFilesMissing(let files):
            return "Model package is incomplete (missing \(files.count) file(s))."
        case .installationFailed(let reason):
            return "Model installation failed: \(reason)"
        }
    }
}

/// Downloads, verifies, and installs the cartoonization model:
/// manifest → zip download → SHA256 → extraction → expected-file validation
/// → atomic move into Application Support → installed-version tracking.
final class AvatarModelDownloadService: NSObject {

    private let fileManager = FileManager.default

    // MARK: Installed state

    /// Returns the installed, validated model directory, or nil.
    func installedModelDirectory() -> URL? {
        guard let manifest = installedManifest() else { return nil }
        let modelDir = AvatarModelConfiguration.installDirectory
            .appendingPathComponent(manifest.modelDirectory, isDirectory: true)
        guard fileManager.fileExists(atPath: modelDir.path),
              missingFiles(for: manifest, in: AvatarModelConfiguration.installDirectory).isEmpty else {
            return nil
        }
        return modelDir
    }

    func installedManifest() -> AvatarModelManifest? {
        guard let data = try? Data(contentsOf: AvatarModelConfiguration.installedManifestURL) else {
            return nil
        }
        return try? JSONDecoder().decode(AvatarModelManifest.self, from: data)
    }

    func installedSizeBytes() -> Int64? {
        guard let dir = installedModelDirectory(),
              let enumerator = fileManager.enumerator(at: dir, includingPropertiesForKeys: [.fileSizeKey]) else {
            return nil
        }
        var total: Int64 = 0
        for case let url as URL in enumerator {
            total += Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return total
    }

    func removeInstalledModel() throws {
        try? fileManager.removeItem(at: AvatarModelConfiguration.installDirectory)
    }

    // MARK: Install pipeline

    /// Runs the full pipeline. `diagnostics` is updated after every step;
    /// `progress` reports zip download fraction (0…1) when known.
    func install(
        diagnostics: inout AvatarDiagnostics,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        // Two sources: authenticated GitHub API (private repo during
        // testing, token configured in diagnostics) or a plain public URL.
        let manifest: AvatarModelManifest
        let zipRequest: URLRequest

        if let token = AvatarModelConfiguration.githubToken {
            guard let apiURL = AvatarModelConfiguration.githubAPILatestReleaseURL else {
                diagnostics.fail(.manifestConfigured, error: AvatarModelError.notConfigured)
                throw AvatarModelError.notConfigured
            }
            diagnostics.complete(.manifestConfigured)
            do {
                let release = try await fetchRelease(from: apiURL, token: token)
                guard let manifestAssetURL = release.assetURL(named: "model-manifest.json") else {
                    throw AvatarModelError.downloadFailed("release has no model-manifest.json asset")
                }
                let manifestData = try await fetchAsset(from: manifestAssetURL, token: token)
                manifest = try JSONDecoder().decode(AvatarModelManifest.self, from: manifestData)
                guard let zipAssetURL = release.assetURL(named: manifest.zip) else {
                    throw AvatarModelError.downloadFailed("release has no \(manifest.zip) asset")
                }
                zipRequest = Self.request(for: zipAssetURL, token: token, octetStream: true)
                diagnostics.complete(.manifestFetched)
            } catch let error as AvatarModelError {
                diagnostics.fail(.manifestFetched, error: error)
                throw error
            } catch {
                diagnostics.fail(.manifestFetched, error: error)
                throw AvatarModelError.manifestInvalid
            }
        } else {
            guard let manifestURL = AvatarModelConfiguration.manifestURL else {
                diagnostics.fail(.manifestConfigured, error: AvatarModelError.notConfigured)
                throw AvatarModelError.notConfigured
            }
            diagnostics.complete(.manifestConfigured)
            do {
                let (data, response) = try await URLSession.shared.data(from: manifestURL)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    throw AvatarModelError.downloadFailed(
                        "manifest HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)"
                    )
                }
                manifest = try JSONDecoder().decode(AvatarModelManifest.self, from: data)
                zipRequest = URLRequest(url: manifestURL.deletingLastPathComponent()
                    .appendingPathComponent(manifest.zip))
                diagnostics.complete(.manifestFetched)
            } catch let error as AvatarModelError {
                diagnostics.fail(.manifestFetched, error: error)
                throw error
            } catch {
                diagnostics.fail(.manifestFetched, error: error)
                throw AvatarModelError.manifestInvalid
            }
        }

        // 2. Zip download
        let zipLocalURL: URL
        do {
            zipLocalURL = try await download(request: zipRequest, progress: progress)
            diagnostics.complete(.zipDownloaded)
        } catch {
            diagnostics.fail(.zipDownloaded, error: error)
            throw AvatarModelError.downloadFailed(error.localizedDescription)
        }
        defer { try? fileManager.removeItem(at: zipLocalURL) }

        // 3. Checksum
        let digest = try Self.sha256Hex(of: zipLocalURL)
        guard digest.caseInsensitiveCompare(manifest.sha256) == .orderedSame else {
            diagnostics.fail(.checksumVerified, error: AvatarModelError.checksumMismatch)
            throw AvatarModelError.checksumMismatch
        }
        diagnostics.complete(.checksumVerified)

        // 4. Extract to a staging directory, then validate.
        let staging = fileManager.temporaryDirectory
            .appendingPathComponent("avatar-install-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: staging) }
        do {
            try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
            try fileManager.unzipItem(at: zipLocalURL, to: staging)
        } catch {
            diagnostics.fail(.filesValidated, error: error)
            throw AvatarModelError.installationFailed(error.localizedDescription)
        }

        let missing = missingFiles(for: manifest, in: staging)
        guard missing.isEmpty else {
            diagnostics.fail(.filesValidated, error: AvatarModelError.expectedFilesMissing(missing))
            throw AvatarModelError.expectedFilesMissing(missing)
        }
        diagnostics.complete(.filesValidated)

        // 5. Atomic install: replace the previous installation.
        do {
            let installDir = AvatarModelConfiguration.installDirectory
            try? fileManager.removeItem(at: installDir)
            try fileManager.createDirectory(
                at: installDir.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try fileManager.moveItem(at: staging, to: installDir)
            let manifestData = try JSONEncoder().encode(manifest)
            try manifestData.write(to: AvatarModelConfiguration.installedManifestURL, options: .atomic)
        } catch {
            diagnostics.fail(.filesValidated, error: error)
            throw AvatarModelError.installationFailed(error.localizedDescription)
        }

        diagnostics.installedVersion = manifest.version
        diagnostics.installedSizeBytes = installedSizeBytes()

        guard let modelDir = installedModelDirectory() else {
            throw AvatarModelError.installationFailed("installed model failed re-validation")
        }
        return modelDir
    }

    /// Files from the manifest that are missing under `root`.
    func missingFiles(for manifest: AvatarModelManifest, in root: URL) -> [String] {
        manifest.expectedFiles.filter { relative in
            !fileManager.fileExists(atPath: root.appendingPathComponent(relative).path)
        }
    }

    // MARK: Helpers

    /// Builds a GitHub API request; `octetStream` selects raw asset bytes.
    static func request(for url: URL, token: String, octetStream: Bool) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue(
            octetStream ? "application/octet-stream" : "application/vnd.github+json",
            forHTTPHeaderField: "Accept"
        )
        return request
    }

    private func fetchRelease(from url: URL, token: String) async throws -> GitHubRelease {
        let (data, response) = try await URLSession.shared.data(
            for: Self.request(for: url, token: token, octetStream: false)
        )
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AvatarModelError.downloadFailed(
                "release lookup HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1) — check the access token"
            )
        }
        return try JSONDecoder().decode(GitHubRelease.self, from: data)
    }

    private func fetchAsset(from url: URL, token: String) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(
            for: Self.request(for: url, token: token, octetStream: true)
        )
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AvatarModelError.downloadFailed(
                "asset HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)"
            )
        }
        return data
    }

    /// Download with progress via the task's Progress object; the temp file
    /// is copied out before the completion handler returns.
    private func download(
        request: URLRequest,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        let destination = fileManager.temporaryDirectory
            .appendingPathComponent("avatar-download-\(UUID().uuidString).zip")

        var observation: NSKeyValueObservation?
        defer { observation?.invalidate() }

        return try await withCheckedThrowingContinuation { continuation in
            let task = URLSession.shared.downloadTask(with: request) { tempURL, response, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    continuation.resume(throwing: AvatarModelError.downloadFailed(
                        "HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)"
                    ))
                    return
                }
                guard let tempURL else {
                    continuation.resume(throwing: AvatarModelError.downloadFailed("no file received"))
                    return
                }
                do {
                    try FileManager.default.moveItem(at: tempURL, to: destination)
                    continuation.resume(returning: destination)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            observation = task.progress.observe(\.fractionCompleted) { p, _ in
                progress(p.fractionCompleted)
            }
            task.resume()
        }
    }

    /// Streaming SHA256 so large zips never load fully into memory.
    static func sha256Hex(of fileURL: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }
        var hasher = SHA256()
        while autoreleasepool(invoking: {
            let chunk = handle.readData(ofLength: 1 << 20)
            guard !chunk.isEmpty else { return false }
            hasher.update(data: chunk)
            return true
        }) {}
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
