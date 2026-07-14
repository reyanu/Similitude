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
