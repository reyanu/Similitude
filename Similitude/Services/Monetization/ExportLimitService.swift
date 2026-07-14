import Foundation

/// Free-plan export budget: 3 exports per rolling 7-day window, tracked
/// locally. Timestamps older than the window fall out automatically, so
/// the budget "resets" continuously rather than on a fixed weekday.
struct ExportLimitService {

    static let freeExportLimit = 3
    static let windowSeconds: TimeInterval = 7 * 24 * 60 * 60

    private let defaults: UserDefaults
    private let now: () -> Date
    private let key = "export.timestamps"

    /// `defaults` and `now` are injectable for tests.
    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.now = now
    }

    /// Exports recorded within the current rolling window.
    func recentExportDates() -> [Date] {
        let cutoff = now().addingTimeInterval(-Self.windowSeconds)
        return storedDates().filter { $0 > cutoff }
    }

    func remainingFreeExports() -> Int {
        max(0, Self.freeExportLimit - recentExportDates().count)
    }

    func canExport(isPremium: Bool) -> Bool {
        isPremium || remainingFreeExports() > 0
    }

    /// Records one export and prunes expired timestamps. Premium exports
    /// should not be recorded — they are unlimited.
    func recordExport() {
        var dates = recentExportDates()
        dates.append(now())
        defaults.set(dates.map(\.timeIntervalSince1970), forKey: key)
    }

    /// When the next free export becomes available, or nil if any remain.
    func nextFreeExportDate() -> Date? {
        guard remainingFreeExports() == 0,
              let oldest = recentExportDates().min() else { return nil }
        return oldest.addingTimeInterval(Self.windowSeconds)
    }

    private func storedDates() -> [Date] {
        let raw = defaults.array(forKey: key) as? [Double] ?? []
        return raw.map(Date.init(timeIntervalSince1970:))
    }
}
