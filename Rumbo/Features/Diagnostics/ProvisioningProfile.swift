import Foundation

/// Reads `embedded.mobileprovision` so diagnostics can show which entitlements the signing profile grants.
struct ProvisioningProfile {
    let name: String
    let teamName: String
    let expiration: Date?
    let entitlements: [String: Any]

    static func embedded() -> ProvisioningProfile? {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let raw = String(data: data, encoding: .isoLatin1),
              let start = raw.range(of: "<?xml"),
              let end = raw.range(of: "</plist>"),
              let plistData = String(raw[start.lowerBound..<end.upperBound]).data(using: .isoLatin1),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any]
        else { return nil }

        return ProvisioningProfile(
            name: plist["Name"] as? String ?? "?",
            teamName: plist["TeamName"] as? String ?? "?",
            expiration: plist["ExpirationDate"] as? Date,
            entitlements: plist["Entitlements"] as? [String: Any] ?? [:]
        )
    }

    func strings(for key: String) -> [String] {
        if let list = entitlements[key] as? [String] { return list }
        if let single = entitlements[key] as? String { return [single] }
        return []
    }
}
