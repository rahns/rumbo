import Foundation
import RumboCore

/// The language being learned right now, for wording that isn't inside a view with the model at hand
/// (task titles, reminders, links). The app sets it from the active profile (`AppModel.setLanguage`);
/// widgets set it from the snapshot they draw. See docs/09-multi-language.md.
enum ActiveLanguage {
    static let defaultsKey = "language.active"

    /// The active language's pack. Spanish until a language has been chosen.
    private(set) static var pack = LanguagePack.pack(for: UserDefaults.standard.string(forKey: defaultsKey))

    /// The learner's level in that language. Below A2 the app's words are English (`Band.usesEnglishInterface`).
    private(set) static var band: Band = .a2_1

    static var code: String { pack.code }
    /// The words to show: the language's from A2, English for a beginner (Pico's cheers stay the language's).
    static var phrases: Phrasebook { pack.phrases(for: band) }
    static var dateLocale: Locale { pack.dateLocale(for: band) }

    /// A level's name as the learner sees it.
    static func levelName(_ level: Band) -> String { pack.levelName(level, learnerAt: band) }

    /// Called by the app whenever the learner's level may have changed (and by widgets from their snapshot).
    static func setBand(_ band: Band?) {
        self.band = band ?? .a2_1
    }
    /// The language's name in English, for sentences ("A little Spanish today…").
    static var name: String { pack.name }

    /// Makes `code` the active language and remembers it for the next launch.
    static func set(_ code: String) {
        pack = LanguagePack.pack(for: code)
        UserDefaults.standard.set(pack.code, forKey: defaultsKey)
    }

    /// Uses a language without remembering it (widgets drawing a snapshot).
    static func use(_ code: String?) {
        pack = LanguagePack.pack(for: code)
    }
}
