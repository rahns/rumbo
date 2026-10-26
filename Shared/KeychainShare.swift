import Foundation
import Security

/// Shares small values between the app and its widgets through a Keychain access group.
/// Used when the App Group entitlement isn't available: development profiles usually grant
/// `keychain-access-groups: TEAMID.*`, which covers a group both targets can use.
enum KeychainShare {
    private static let groupSuffix = "com.rahns.rumbo.shared"
    private static let service = "com.rahns.rumbo.shared"

    /// The team prefix (e.g. `ABCDE12345`), read from the access group the Keychain assigns by default.
    static var teamPrefix: String? {
        let probe: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.rahns.rumbo.probe",
            kSecAttrAccount as String: "probe",
        ]
        var result: CFTypeRef?
        var status = SecItemCopyMatching(probe.merging([kSecReturnAttributes as String: true]) { $1 } as CFDictionary, &result)
        if status == errSecItemNotFound {
            var add = probe
            add[kSecValueData as String] = Data("probe".utf8)
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            add[kSecReturnAttributes as String] = true
            status = SecItemAdd(add as CFDictionary, &result)
        }
        guard status == errSecSuccess,
              let attributes = result as? [String: Any],
              let group = attributes[kSecAttrAccessGroup as String] as? String
        else { return nil }
        return group.components(separatedBy: ".").first
    }

    static var accessGroup: String? {
        teamPrefix.map { "\($0).\(groupSuffix)" }
    }

    @discardableResult
    static func write(_ data: Data, forKey key: String) -> OSStatus {
        guard let accessGroup else { return errSecMissingEntitlement }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrAccessGroup as String: accessGroup,
        ]
        let update: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        guard status == errSecItemNotFound else { return status }
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(add as CFDictionary, nil)
    }

    static func read(forKey key: String) -> (data: Data?, status: OSStatus) {
        guard let accessGroup else { return (nil, errSecMissingEntitlement) }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrAccessGroup as String: accessGroup,
            kSecReturnData as String: true,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return (result as? Data, status)
    }

    static func describe(_ status: OSStatus) -> String {
        let message = SecCopyErrorMessageString(status, nil) as String? ?? "unknown"
        return "\(status) (\(message))"
    }
}
