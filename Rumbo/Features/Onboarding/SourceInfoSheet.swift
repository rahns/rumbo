import RumboCore
import SwiftUI

extension SourceKind: @retroactive Identifiable {
    public var id: String { rawValue }
}

/// What each source is in the language being learned, for someone who hasn't heard of it: what it is and where to find it. Opened by tapping a source in onboarding or Settings → Sources.
struct SourceInfoSheet: View {
    let source: SourceKind

    /// The wording comes from the language being learned (`LanguagePack.sources`).
    private var info: SourceInfo? { ActiveLanguage.pack.sources[source] }

    var body: some View {
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
                if let info {
                    section("What it is", info.what, symbol: "questionmark.circle.fill")
                    section("Where to find it", info.whereToFind, symbol: "mappin.circle.fill")
                    if let inYourPlan = info.inYourPlan {
                        section("In your plan", inYourPlan, symbol: "calendar.circle.fill")
                    }
                    ForEach(info.links.indices, id: \.self) { index in
                        if let url = URL(string: info.links[index].url) {
                            Link(destination: url) {
                                Label(info.links[index].title, systemImage: "arrow.up.right.square.fill")
                            }
                            .buttonStyle(ChunkySecondaryButtonStyle())
                        }
                    }
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
