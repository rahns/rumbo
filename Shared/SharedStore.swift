import Foundation
import Security

/// Identifiers and the small amount of state shared between the app and its widgets.
/// Tries the App Group first and falls back to a shared Keychain group.
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

    /// Writes the ping through every available channel. Returns whether each one succeeded.
    static func writePing(_ date: Date = .now) -> (appGroup: Bool, keychain: OSStatus) {
        var appGroup = false
        if let defaults {
            defaults.set(date, forKey: pingKey)
            appGroup = true
        }
        let keychain = KeychainShare.write(Data(date.ISO8601Format().utf8), forKey: pingKey)
        return (appGroup, keychain)
    }

    static func readAppGroupPing() -> Date? {
        defaults?.object(forKey: pingKey) as? Date
    }

    static func readKeychainPing() -> (date: Date?, status: OSStatus) {
        let (data, status) = KeychainShare.read(forKey: pingKey)
        let date = data.flatMap { String(data: $0, encoding: .utf8) }.flatMap { try? Date($0, strategy: .iso8601) }
        return (date, status)
    }
}
