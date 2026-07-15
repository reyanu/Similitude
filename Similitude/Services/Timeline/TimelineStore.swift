import UIKit
import Observation

/// One dated milestone in a child's timeline: a portrait plus optional
/// resemblance scores captured at that moment.
struct TimelineEntry: Codable, Identifiable, Equatable {
    let id: UUID
    var date: Date
    var label: String
    var imageFileName: String
    var momScorePercent: Int?
    var dadScorePercent: Int?
    var strongestTraits: [String]
}

enum TimelineError: LocalizedError {
    case freeLimitReached
    case persistenceFailed(String)

    var errorDescription: String? {
        switch self {
        case .freeLimitReached:
            return "The free plan saves one timeline entry. Upgrade to Premium for unlimited history."
        case .persistenceFailed(let reason):
            return "The timeline entry could not be saved: \(reason)"
        }
    }
}

/// Local-only storage for the Family Timeline: a JSON index plus JPEG
/// portraits in Application Support. No cloud backup in V1 — photos never
/// leave the device.
@Observable
@MainActor
final class TimelineStore {

    static let shared = TimelineStore()

    /// Entries sorted oldest → newest.
    private(set) var entries: [TimelineEntry] = []

    private let directory: URL
    private var indexURL: URL { directory.appendingPathComponent("timeline-index.json") }

    /// `directory` is injectable for tests.
    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Timeline", isDirectory: true)
        loadIndex()
    }

    // MARK: Plan limits

    /// Free plan: one saved entry. Premium: unlimited.
    func canAddEntry(isPremium: Bool) -> Bool {
        isPremium || entries.isEmpty
    }

    // MARK: Mutations

    @discardableResult
    func addEntry(
        image: UIImage,
        date: Date,
        label: String,
        momScorePercent: Int? = nil,
        dadScorePercent: Int? = nil,
        strongestTraits: [String] = [],
        isPremium: Bool
    ) throws -> TimelineEntry {
        guard canAddEntry(isPremium: isPremium) else {
            throw TimelineError.freeLimitReached
        }

        let id = UUID()
        let fileName = "\(id.uuidString).jpg"
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            guard let data = image.jpegData(compressionQuality: 0.9) else {
                throw TimelineError.persistenceFailed("could not encode image")
            }
            try data.write(to: directory.appendingPathComponent(fileName), options: .atomic)
        } catch let error as TimelineError {
            throw error
        } catch {
            throw TimelineError.persistenceFailed(error.localizedDescription)
        }

        let entry = TimelineEntry(
            id: id,
            date: date,
            label: label,
            imageFileName: fileName,
            momScorePercent: momScorePercent,
            dadScorePercent: dadScorePercent,
            strongestTraits: strongestTraits
        )
        entries.append(entry)
        entries.sort { $0.date < $1.date }
        try saveIndex()
        return entry
    }

    func deleteEntry(id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        let entry = entries.remove(at: index)
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(entry.imageFileName))
        try? saveIndex()
    }

    func image(for entry: TimelineEntry) -> UIImage? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent(entry.imageFileName)) else {
            return nil
        }
        return UIImage(data: data)
    }

    // MARK: Persistence

    private func loadIndex() {
        guard let data = try? Data(contentsOf: indexURL),
              let loaded = try? JSONDecoder().decode([TimelineEntry].self, from: data) else {
            return
        }
        entries = loaded.sorted { $0.date < $1.date }
    }

    private func saveIndex() throws {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(entries)
            try data.write(to: indexURL, options: .atomic)
        } catch {
            throw TimelineError.persistenceFailed(error.localizedDescription)
        }
    }
}
