import Foundation

/// Identifiers and the small amount of state shared between the app and its widgets.
enum SharedStore {
    static let appGroupID = "group.com.rahns.rumbo"
    static let cloudContainerID = "iCloud.com.rahns.rumbo"

    private static let pingKey = "diagnostics.lastPing"

    /// `nil` when the App Group entitlement didn't survive signing.
    static var defaults: UserDefaults? {
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil else {
            return nil
        }
        return UserDefaults(suiteName: appGroupID)
    }

    static func writePing(_ date: Date = .now) -> Bool {
        guard let defaults else { return false }
        defaults.set(date, forKey: pingKey)
        return true
    }

    static func readPing() -> Date? {
        defaults?.object(forKey: pingKey) as? Date
    }
}
