import RumboCore
import SwiftUI

/// Library tab (docs/03-experience.md §3.5): shows and podcasts for the learner's level now and next.
/// "Watching this" makes "Watch or listen" tasks point at it.
struct LibraryView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                if let profile = model.profile {
                    let suggestions = model.contentSuggestions
                    VStack(alignment: .leading, spacing: 18) {
                        intro(profile)
                        if let current = model.currentContent {
                            section("Watching now", subtitle: nil) {
                                ContentCard(item: current, isWatching: true, toggle: { model.toggleWatching(current) }, open: open)
                            }
                        }
                        section("For your level", subtitle: "\(profile.band.label) · \(profile.band.rawValue)") {
                            let others = suggestions.now.filter { $0.id != model.currentContent?.id }
                            if others.isEmpty {
                                Text("That's everything for your level right now. New suggestions arrive with app updates and when you level up.")
                                    .font(.rounded(.subheadline, weight: .medium))
                                    .foregroundStyle(Palette.secondaryText)
                            }
                            ForEach(others) { item in
                                ContentCard(item: item, isWatching: false, toggle: { model.toggleWatching(item) }, open: open)
                            }
                        }
                        if !suggestions.next.isEmpty, let next = profile.band.next {
                            section("Coming up", subtitle: "For \(next.label) · \(next.rawValue). Try one early if it feels fun, not frustrating.") {
                                ForEach(suggestions.next) { item in
                                    ContentCard(item: item, isWatching: item.id == model.currentContent?.id, toggle: { model.toggleWatching(item) }, open: open)
                                        .opacity(0.85)
                                }
                            }
                        }
                        Text(model.catalogStatus.isEmpty ? "Suggestions list v\(model.catalog.version) · pull down to check for new ones" : model.catalogStatus)
                            .font(.rounded(.caption, weight: .semibold))
                            .foregroundStyle(Palette.secondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                    }
                    .padding(20)
                }
            }
            .background(Palette.background.ignoresSafeArea())
            .navigationTitle("Library")
            .task { await model.refreshCatalog() }
            .refreshable { await model.refreshCatalog() }
        }
    }

    private func intro(_ profile: LearnerProfile) -> some View {
        HStack(alignment: .top, spacing: 12) {
            PicoBadge(size: 54, mood: .listening, celebrate: 0)
            Text("Real shows and podcasts for when you want a change from your courses. \"Watch or listen\" tasks use the one you're watching.")
                .font(.rounded(.subheadline, weight: .semibold))
                .foregroundStyle(Palette.secondaryText)
        }
    }

    private func section<Content: View>(_ title: String, subtitle: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.rounded(.title3, weight: .black))
                .foregroundStyle(Palette.ink)
            if let subtitle {
                Text(subtitle)
                    .font(.rounded(.subheadline, weight: .semibold))
                    .foregroundStyle(Palette.secondaryText)
            }
            content()
        }
    }

    private func open(_ url: URL) {
        openURL(url)
    }
}

struct ContentCard: View {
    let item: ContentItem
    let isWatching: Bool
    let toggle: () -> Void
    let open: (URL) -> Void

    var body: some View {
        RaisedCard(accent: color) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: symbol)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(color))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.rounded(.headline, weight: .black))
                            .foregroundStyle(Palette.ink)
                        Text("\(kindLabel) · \(item.country) · \(item.from == item.to ? item.from.rawValue : "\(item.from.rawValue)–\(item.to.rawValue)")")
                            .font(.rounded(.caption, weight: .bold))
                            .foregroundStyle(Palette.secondaryText)
                    }
                    Spacer(minLength: 0)
                }
                Text(item.why)
                    .font(.rounded(.subheadline, weight: .medium))
                    .foregroundStyle(Palette.ink)
                Label(item.whereToFind, systemImage: "mappin.and.ellipse")
                    .font(.rounded(.caption, weight: .semibold))
                    .foregroundStyle(Palette.secondaryText)
                HStack(spacing: 10) {
                    Button(action: toggle) {
                        Label(isWatching ? "Watching" : "Watch this", systemImage: isWatching ? "checkmark.circle.fill" : "plus.circle")
                    }
                    .buttonStyle(ChunkyButtonStyle(color: isWatching ? Palette.leaf : color, foreground: item.kind == .film && !isWatching ? Palette.inkOnBright : .white))
                    if let url = item.url.flatMap(URL.init(string:)) {
                        Button { open(url) } label: {
                            Label("Open", systemImage: "arrow.up.forward.app.fill")
                        }
                        .buttonStyle(ChunkySecondaryButtonStyle(fullWidth: false))
                    }
                }
                .sensoryFeedback(.success, trigger: isWatching)
            }
        }
    }

    private var symbol: String {
        switch item.kind {
        case .series: "tv.fill"
        case .film: "film.fill"
        case .podcast: "headphones"
        case .youtube: "play.rectangle.fill"
        }
    }

    private var kindLabel: String {
        switch item.kind {
        case .series: "Series"
        case .film: "Film"
        case .podcast: "Podcast"
        case .youtube: "YouTube"
        }
    }

    private var color: Color {
        switch item.kind {
        case .series: Palette.coral
        case .film: Palette.sun
        case .podcast: Palette.sky
        case .youtube: Palette.leaf
        }
    }
}
