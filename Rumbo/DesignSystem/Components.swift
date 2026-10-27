import SwiftUI

/// Duolingo-style "3D" button: a solid face over a darker bottom edge that presses down on tap.
struct ChunkyButtonStyle: ButtonStyle {
    var color: Color = Palette.coral
    var foreground: Color = .white
    var edgeHeight: CGFloat = 4
    var fullWidth = true

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(.rounded(.headline, weight: .heavy))
            .textCase(.uppercase)
            .foregroundStyle(foreground)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(color))
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(color.edge())
                    .offset(y: pressed ? 0 : edgeHeight)
            )
            .offset(y: pressed ? edgeHeight : 0)
            .padding(.bottom, edgeHeight)
            .animation(.spring(response: 0.18, dampingFraction: 0.6), value: pressed)
            .sensoryFeedback(.impact(weight: .light), trigger: pressed) { _, new in new }
    }
}

/// Quieter variant for secondary actions: white face, grey edge.
struct ChunkySecondaryButtonStyle: ButtonStyle {
    var fullWidth = true

    func makeBody(configuration: Configuration) -> some View {
        ChunkyButtonStyle(color: Palette.card, foreground: Palette.ink, fullWidth: fullWidth)
            .makeBody(configuration: configuration)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Palette.cardEdge, lineWidth: 2)
                    .padding(.bottom, 4)
                    .offset(y: configuration.isPressed ? 4 : 0)
            )
    }
}

/// Raised card with a soft bottom edge.
struct RaisedCard<Content: View>: View {
    var accent: Color? = nil
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Palette.card)
            )
            .overlay(alignment: .leading) {
                if let accent {
                    UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 20, style: .continuous)
                        .fill(accent)
                        .frame(width: 6)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Palette.cardEdge)
                    .offset(y: 4)
            )
            .padding(.bottom, 4)
    }
}

/// Selectable pill, used for the daily budget and other small choices.
struct ChipButton: View {
    let title: String
    let isSelected: Bool
    var color: Color = Palette.coral
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.rounded(.subheadline, weight: .heavy))
                .foregroundStyle(isSelected ? .white : Palette.ink)
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(Capsule().fill(isSelected ? color : Palette.lilac))
                .background(Capsule().fill(isSelected ? color.edge() : Palette.lilac.edge(0.08)).offset(y: 3))
                .padding(.bottom, 3)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

/// Thick rounded progress bar with a highlight stripe.
struct ChunkyProgressBar: View {
    let value: Double
    var color: Color = Palette.leaf
    var height: CGFloat = 14
    /// A light sweep runs along the fill whenever the value goes up.
    var shimmers = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Position of the shimmer band, from -0.4 (before the start) to 1.4 (past the end).
    @State private var sweep: CGFloat = -0.4

    var body: some View {
        GeometryReader { proxy in
            let fillWidth = max(height, proxy.size.width * min(max(value, 0), 1))
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.lilac)
                Capsule()
                    .fill(color)
                    .frame(width: fillWidth)
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(.white.opacity(0.35))
                            .frame(height: height * 0.25)
                            .padding(.horizontal, height * 0.4)
                            .padding(.top, height * 0.2)
                    }
                    .overlay {
                        if shimmers {
                            // The band slides across the fill, clipped to it.
                            ZStack {
                                LinearGradient(colors: [.white.opacity(0), .white.opacity(0.7), .white.opacity(0)], startPoint: .leading, endPoint: .trailing)
                                    .frame(width: max(30, fillWidth * 0.35))
                                    .offset(x: fillWidth * (sweep - 0.5))
                            }
                            .frame(width: fillWidth, height: height)
                            .clipShape(Capsule())
                            .allowsHitTesting(false)
                        }
                    }
                    .opacity(value > 0 ? 1 : 0)
            }
        }
        .frame(height: height)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: value)
        .onChange(of: value) { old, new in
            guard shimmers, new > old, !reduceMotion else { return }
            sweep = -0.4
            withAnimation(.easeInOut(duration: 0.9).delay(0.3)) { sweep = 1.4 }
        }
        .accessibilityElement()
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int((min(max(value, 0), 1) * 100).rounded())) percent")
    }
}
