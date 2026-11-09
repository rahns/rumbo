import RumboCore
import SwiftUI

extension SourceKind: @retroactive Identifiable {
    public var id: String { rawValue }
}

/// What each source is, for someone who hasn't heard of it: what it is, where to find it, what it costs and
/// how Rumbo uses it. Opened by tapping a source in onboarding or Settings → Sources.
struct SourceInfoSheet: View {
    let source: SourceKind

    private struct Info {
        let what: String
        let whereToFind: String
        let cost: String
        let inRumbo: String
        let links: [(title: String, url: URL)]
    }

    private var info: Info {
        switch source {
        case .dreamingSpanish:
            Info(what: "A video library of Spanish made to be understood: thousands of videos where native speakers explain, chat and tell stories, using pictures and gestures at the easy levels. Every video has a difficulty from 0 to 100, and it counts your hours of listening. It's built on comprehensible input: you pick up Spanish by understanding lots of it.",
                 whereToFind: "The Dreaming Spanish app (iPhone, Android, TV) and dreaming.com.",
                 cost: "Many videos are free on YouTube; a subscription unlocks the full library and progress tracking.",
                 inRumbo: "Your main listening: Rumbo plans videos at your difficulty range (e.g. 40–45), sometimes easier ones for fluency, asks what level you watched and charts it on Progress. Its hours count toward your level.",
                 links: [("Open dreaming.com", URL(string: "https://www.dreaming.com/spanish")!)])
        case .languageTransfer:
            Info(what: "\"Complete Spanish\": a free audio course of 90 short tracks. A teacher guides a student to build sentences by thinking, not memorising, and you answer out loud before the student does. It gives you the skeleton of Spanish grammar from A2 to early B1.",
                 whereToFind: "The free Language Transfer app (iPhone and Android) or languagetransfer.org.",
                 cost: "Free (it's run on donations).",
                 inRumbo: "Grammar & vocab: Rumbo plans the next track at its real length and asks which track you're up to when you log it.",
                 links: [("Open languagetransfer.org", URL(string: "https://www.languagetransfer.org")!)])
        case .extraEnEspanol:
            Info(what: "A sitcom made for Spanish learners: 13 episodes about flatmates in Spain and an American friend who arrives knowing little Spanish. The speech is clear and slow at first, and it's funny.",
                 whereToFind: "Free on YouTube: search \"Extra en Español\".",
                 cost: "Free.",
                 inRumbo: "Listening with subtitles: at A2 it's planned half an episode at a time, watched with Spanish subtitles, then a short scene to shadow (speak along with the actors). At B1, whole episodes for enjoyment.",
                 links: [("Search on YouTube", URL(string: "https://www.youtube.com/results?search_query=Extra%20en%20Espa%C3%B1ol")!)])
        case .duolingo:
            Info(what: "The green-owl app of short, game-like lessons and a daily streak.",
                 whereToFind: "The Duolingo app (iPhone and Android) and duolingo.com.",
                 cost: "Free with ads; Super is optional.",
                 inRumbo: "A short daily warm-up (about 3 minutes, never more than 5), mainly to keep your Duolingo streak alive. Rumbo keeps track of your section and unit. It fades out at B2. You can stop it being planned every day in Settings → Habit.",
                 links: [("Open duolingo.com", URL(string: "https://www.duolingo.com")!)])
        case .writing:
            Info(what: "Short writing tasks inside Rumbo: guided writing with a prompt, and quick timed writes.",
                 whereToFind: "Right here in Rumbo; there's nothing else to install.",
                 cost: "Free. Feedback uses your own free Gemini or Groq key (Settings → Writing feedback), or a basic checker without one.",
                 inRumbo: "Speaking & writing practice: Pico checks your writing, explains each mistake, and every correction becomes a card in the Mistakes tab to review later.",
                 links: [])
        case .tandem:
            Info(what: "Language-exchange apps where you chat with native Spanish speakers who are learning your language: you help each other.",
                 whereToFind: "The Tandem and HelloTalk apps (iPhone and Android).",
                 cost: "Free to use; both have optional paid plans.",
                 inRumbo: "Speaking & writing: Rumbo plans messages with your partner first, then voice notes, then short calls as your listening grows (you can switch these on early in Settings → Speaking). Save your partner's corrections to the Mistakes tab.",
                 links: [("Open tandem.net", URL(string: "https://www.tandem.net")!), ("Open hellotalk.com", URL(string: "https://www.hellotalk.com")!)])
        case .suggestedContent:
            Info(what: "Real shows, series, podcasts and YouTube channels made for native speakers, picked for each level in Rumbo's Library.",
                 whereToFind: "The Library tab: each suggestion says where to find it (YouTube, Netflix, Spotify, …).",
                 cost: "Many are free; some need a streaming subscription.",
                 inRumbo: "Listening once the courses run out, from B1, or if you don't use Dreaming Spanish. Mark one \"Watch this\" in the Library and the \"Watch or listen\" task points at it.",
                 links: [])
        }
    }

    var body: some View {
        let info = info
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    Image(systemName: SourceCopy.symbol(source))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Palette.coral))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(SourceCopy.name(source))
                            .font(.rounded(.title2, weight: .black))
                            .foregroundStyle(Palette.ink)
                        Text(SourceCopy.role(source))
                            .font(.rounded(.subheadline, weight: .semibold))
                            .foregroundStyle(Palette.secondaryText)
                    }
                }
                section("What it is", info.what, symbol: "questionmark.circle.fill")
                section("Where to find it", info.whereToFind, symbol: "mappin.circle.fill")
                section("Cost", info.cost, symbol: "creditcard.fill")
                section("How Rumbo uses it", info.inRumbo, symbol: "sparkles")
                ForEach(info.links.indices, id: \.self) { index in
                    Link(destination: info.links[index].url) {
                        Label(info.links[index].title, systemImage: "arrow.up.right.square.fill")
                    }
                    .buttonStyle(ChunkySecondaryButtonStyle())
                }
            }
            .padding(24)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Palette.background)
    }

    private func section(_ title: String, _ text: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol)
                .font(.rounded(.headline, weight: .black))
                .foregroundStyle(Palette.ink)
            Text(text)
                .font(.rounded(.subheadline, weight: .medium))
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
