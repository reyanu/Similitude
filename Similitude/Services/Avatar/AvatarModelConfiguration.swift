import Foundation

/// Where the cartoonization model comes from and where it lives on disk.
enum AvatarModelConfiguration {

    /// Manifest published by the package-cartoonization-model workflow.
    /// Until the first model release exists, downloads fail with a clear
    /// error — the feature is never faked.
    static let defaultManifestURL = URL(
        string: "https://github.com/reyanu/Similitude/releases/latest/download/model-manifest.json"
    )

    /// Developer override (set from the diagnostics screen) so a release
    /// candidate can be tested without shipping a new app build.
    static let overrideDefaultsKey = "avatar.manifestURLOverride"

    /// The GitHub repository hosting model releases.
    static let githubRepository = "reyanu/Similitude"

    /// Latest model release via the GitHub API (works for private repos
    /// when a token is configured).
    static var githubAPILatestReleaseURL: URL? {
        URL(string: "https://api.github.com/repos/\(githubRepository)/releases/latest")
    }

    /// Optional fine-grained PAT (contents: read on the repo) entered on
    /// the diagnostics screen, used only while the repo is private during
    /// testing. Never ship a build with a token to the public App Store —
    /// remove it and make the release assets public instead.
    static let githubTokenKey = "avatar.githubToken"

    static var githubToken: String? {
        let raw = UserDefaults.standard.string(forKey: githubTokenKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (raw?.isEmpty ?? true) ? nil : raw
    }

    static var manifestURL: URL? {
        if let raw = UserDefaults.standard.string(forKey: overrideDefaultsKey),
           let url = URL(string: raw), url.scheme == "https" {
            return url
        }
        return defaultManifestURL
    }

    /// Application Support/AvatarModel — excluded from user-visible storage.
    static var installDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("AvatarModel", isDirectory: true)
    }

    /// Marker file recording the installed model's manifest.
    static var installedManifestURL: URL {
        installDirectory.appendingPathComponent("installed-manifest.json")
    }
}

/// Minimal GitHub release shape used to locate model assets by name.
struct GitHubRelease: Codable {
    struct Asset: Codable {
        let name: String
        /// API asset URL; downloading requires Accept: application/octet-stream.
        let url: String
    }

    let tag_name: String
    let assets: [Asset]

    func assetURL(named name: String) -> URL? {
        assets.first { $0.name == name }.flatMap { URL(string: $0.url) }
    }
}

/// The release manifest produced by the packaging workflow.
struct AvatarModelManifest: Codable, Equatable {
    let version: String
    /// Zip file name, resolved relative to the manifest URL.
    let zip: String
    let sha256: String
    let sizeBytes: Int64
    /// Directory name of the compiled model inside the zip.
    let modelDirectory: String
    /// Paths (relative to the install directory) that must exist after
    /// extraction for the install to be considered valid.
    let expectedFiles: [String]
}
