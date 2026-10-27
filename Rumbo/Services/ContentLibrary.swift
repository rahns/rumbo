import Foundation
import RumboCore

/// The content catalog (docs/06-content-catalog.md): bundled with the app, refreshed from GitHub when online.
/// A downloaded copy is cached and used only when its version is newer than the bundled one.
enum ContentLibrary {
    static let remoteURL = URL(string: "https://raw.githubusercontent.com/rahns/rumbo/main/Rumbo/Resources/catalog/content.json")!

    private static var cacheURL: URL {
        URL.cachesDirectory.appendingPathComponent("content-catalog.json")
    }

    static var bundled: ContentCatalog {
        guard let url = Bundle.main.url(forResource: "content", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? ContentCatalog.decode(data)
        else { return ContentCatalog(version: 0, items: []) }
        return catalog
    }

    /// The newest catalog available without the network.
    static func load() -> ContentCatalog {
        let bundled = bundled
        if let data = try? Data(contentsOf: cacheURL), let cached = try? ContentCatalog.decode(data), cached.version > bundled.version {
            return cached
        }
        return bundled
    }

    /// Downloads the latest catalog; returns it only if it's newer than `current`.
    static func fetchNewer(than current: ContentCatalog) async -> ContentCatalog? {
        var request = URLRequest(url: remoteURL)
        request.timeoutInterval = 15
        guard let result = try? await URLSession.shared.data(for: request),
              (result.1 as? HTTPURLResponse)?.statusCode == 200,
              let remote = try? ContentCatalog.decode(result.0),
              remote.version > current.version
        else { return nil }
        try? result.0.write(to: cacheURL, options: .atomic)
        return remote
    }
}
