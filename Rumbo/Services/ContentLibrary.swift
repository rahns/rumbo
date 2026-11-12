import Foundation
import RumboCore

/// The content catalog (docs/06-content-catalog.md): bundled with the app, refreshed from GitHub when online.
/// A downloaded copy is cached and used only when its version is newer than the bundled one.
/// Each language has its own list (`LanguagePack.catalog`).
enum ContentLibrary {
    private static func cacheURL(_ pack: LanguagePack) -> URL {
        URL.cachesDirectory.appendingPathComponent(pack.catalog.cacheFile)
    }

    static func bundled(_ pack: LanguagePack) -> ContentCatalog {
        guard let url = Bundle.main.url(forResource: pack.catalog.resource, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? ContentCatalog.decode(data)
        else { return ContentCatalog(version: 0, items: []) }
        return catalog
    }

    /// The newest catalog available without the network.
    static func load(_ pack: LanguagePack) -> ContentCatalog {
        let bundled = bundled(pack)
        if let data = try? Data(contentsOf: cacheURL(pack)), let cached = try? ContentCatalog.decode(data), cached.version > bundled.version {
            return cached
        }
        return bundled
    }

    enum CheckResult {
        case updated(ContentCatalog)
        case upToDate(version: Int)
        case failed(String)
    }

    /// Downloads the latest catalog. Skips every local HTTP cache, so a new version shows up straight away.
    static func check(against current: ContentCatalog, pack: LanguagePack) async -> CheckResult {
        guard let remoteURL = URL(string: pack.catalog.remoteURL) else { return .failed("No list for \(pack.name).") }
        var request = URLRequest(url: remoteURL, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 20)
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        let data: Data
        do {
            let (body, response) = try await URLSession.shared.data(for: request)
            guard let status = (response as? HTTPURLResponse)?.statusCode, status == 200 else {
                return .failed("The server answered \((response as? HTTPURLResponse)?.statusCode ?? 0).")
            }
            data = body
        } catch {
            return .failed(error.localizedDescription)
        }
        let remote: ContentCatalog
        do {
            remote = try ContentCatalog.decode(data)
        } catch {
            return .failed("The downloaded list couldn't be read (\(error.localizedDescription)).")
        }
        guard remote.version > current.version else { return .upToDate(version: current.version) }
        try? data.write(to: cacheURL(pack), options: .atomic)
        return .updated(remote)
    }
}
