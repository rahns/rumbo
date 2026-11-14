import RumboCore
import SwiftUI

/// Settings → Credits: where Rumbo's material comes from, and whose names it mentions.
struct CreditsView: View {
    var body: some View {
        Form {
            Group {
                Section("Research and standards") {
                    entry("Common European Framework of Reference (CEFR)",
                          "The levels (A1 to B2) and the \"I can…\" self-assessment questions are adapted from the CEFR and its self-assessment grid, © Council of Europe.")
                    entry("The four strands",
                          "The balance between listening, speaking & writing, grammar & vocab and fluency follows Paul Nation's \"four strands\" of language learning.")
                }
                Section("Learning sources") {
                    entry("Other companies' products",
                          "Dreaming Spanish, Dreaming French, Language Transfer, Extra, Duolingo, Tandem and HelloTalk are trademarks of their owners. Rumbo plans time around them and opens them, but isn't made by, connected to or endorsed by any of them.")
                    entry("Suggested shows and podcasts",
                          "The titles in the Library belong to their owners. Rumbo only suggests them and says where to find them.")
                }
                Section("Writing feedback") {
                    entry("AI checkers", "Gemini (Google) and GroqCloud, with your own free API keys.")
                    entry("Basic checker", "LanguageTool's public API, and Apple's on-device model.")
                }
            }
            .rumboRows()
        }
        .rumboListBackground()
        .navigationTitle("Credits")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func entry(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.rounded(.subheadline, weight: .bold))
                .foregroundStyle(Palette.ink)
            Text(text)
                .font(.rounded(.subheadline, weight: .medium))
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }
}
