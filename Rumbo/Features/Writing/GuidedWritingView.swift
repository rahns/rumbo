import RumboCore
import SwiftUI

/// `write.guided`: write → check → feedback → rewrite → compare (R11: correction works best followed by revision).
/// Lives inside the task session; the session saves the draft, feedback and rewrite when the task is logged.
struct GuidedWritingView: View {
    @Binding var draft: String
    @Binding var rewrite: String
    @Binding var feedback: CorrectionService.Result?
    let band: Band
    let prompt: String

    @State private var stage = Stage.writing
    @State private var errorMessage: String?

    enum Stage: Equatable {
        case writing, checking, feedback, rewriting, compare
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch stage {
            case .writing: writing
            case .checking: checking
            case .feedback: feedbackView
            case .rewriting: rewriting
            case .compare: compare
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: stage)
        .onAppear {
            // Back into a draft that was already checked: pick up where it was left.
            if stage == .writing, feedback != nil {
                stage = rewrite.isEmpty ? .feedback : .rewriting
            }
        }
    }

    // MARK: Stages

    private var writing: some View {
        VStack(alignment: .leading, spacing: 12) {
            editor(text: $draft, placeholder: "Escribe aquí…")
            wordCount(draft, target: Prompts.wordTarget(for: band))
            if let errorMessage {
                Text(errorMessage)
                    .font(.rounded(.footnote, weight: .semibold))
                    .foregroundStyle(Palette.coral)
            }
            Button {
                Task { await check() }
            } label: {
                Label("Check my writing", systemImage: "text.badge.checkmark")
            }
            .buttonStyle(ChunkyButtonStyle(color: Palette.sky))
            .disabled(words(in: draft) < 5)
            Text("Write first, without looking things up. Pico checks it after.")
                .font(.rounded(.caption, weight: .medium))
                .foregroundStyle(Palette.secondaryText)
        }
    }

    private var checking: some View {
        VStack(spacing: 14) {
            PicoView(mood: .listening, size: 110)
            Text("Pico is reading your Spanish…")
                .font(.rounded(.headline, weight: .heavy))
                .foregroundStyle(Palette.ink)
            ProgressView()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    @ViewBuilder
    private var feedbackView: some View {
        if let feedback {
            if let notice = feedback.notice {
                Label(notice, systemImage: "exclamationmark.triangle.fill")
                    .font(.rounded(.caption, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Palette.sun.opacity(0.25)))
            }
            if !feedback.strengths.isEmpty {
                RaisedCard(accent: Palette.leaf) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Nice work", systemImage: "hand.thumbsup.fill")
                            .font(.rounded(.headline, weight: .black))
                            .foregroundStyle(Palette.leaf)
                        ForEach(feedback.strengths, id: \.self) { strength in
                            Text(strength).font(.rounded(.subheadline, weight: .medium)).foregroundStyle(Palette.ink)
                        }
                    }
                }
            }
            RaisedCard(accent: Palette.coral) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(feedback.corrections.isEmpty ? "No errors found. ¡Muy bien!" : "Your text")
                        .font(.rounded(.headline, weight: .black))
                        .foregroundStyle(Palette.ink)
                    Text(highlighted(draft, feedback.corrections))
                        .font(.rounded(.body, weight: .medium))
                        .foregroundStyle(Palette.ink)
                }
            }
            ForEach(Array(feedback.corrections.enumerated()), id: \.offset) { _, correction in
                CorrectionRow(correction: correction)
            }
            if !feedback.naturalRewrite.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("A native speaker might say")
                        .font(.rounded(.subheadline, weight: .heavy))
                        .foregroundStyle(Palette.secondaryText)
                    Text(feedback.naturalRewrite)
                        .font(.rounded(.body, weight: .medium))
                        .foregroundStyle(Palette.ink)
                        .textSelection(.enabled)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14).fill(Palette.cream))
            }
            Text("Checked by \(feedback.engine). Each correction is saved to your mistake deck when you finish.")
                .font(.rounded(.caption, weight: .medium))
                .foregroundStyle(Palette.secondaryText)
            HStack(spacing: 10) {
                Button("Edit draft") { stage = .writing }
                    .buttonStyle(ChunkySecondaryButtonStyle())
                Button("Rewrite it") {
                    if rewrite.isEmpty { rewrite = draft }
                    stage = .rewriting
                }
                .buttonStyle(ChunkyButtonStyle(color: Palette.sky))
            }
        }
    }

    private var rewriting: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fix it yourself, using the notes")
                .font(.rounded(.headline, weight: .black))
                .foregroundStyle(Palette.ink)
            ForEach(Array((feedback?.corrections ?? []).enumerated()), id: \.offset) { _, correction in
                HStack(spacing: 6) {
                    Text(correction.original).strikethrough().foregroundStyle(Palette.coral)
                    Image(systemName: "arrow.right").font(.caption).foregroundStyle(Palette.secondaryText)
                    Text(correction.corrected).foregroundStyle(Palette.leaf)
                }
                .font(.rounded(.subheadline, weight: .bold))
            }
            editor(text: $rewrite, placeholder: "")
            HStack(spacing: 10) {
                Button("Back") { stage = .feedback }
                    .buttonStyle(ChunkySecondaryButtonStyle())
                Button("Compare") { stage = .compare }
                    .buttonStyle(ChunkyButtonStyle(color: Palette.leaf))
            }
        }
    }

    private var compare: some View {
        VStack(alignment: .leading, spacing: 12) {
            comparison("Before", draft, Palette.coral)
            comparison("After", rewrite, Palette.leaf)
            Button("Edit again") { stage = .rewriting }
                .buttonStyle(ChunkySecondaryButtonStyle())
            Text("Tap \"I'm done\" to save it and log the time.")
                .font(.rounded(.caption, weight: .medium))
                .foregroundStyle(Palette.secondaryText)
        }
    }

    // MARK: Pieces

    private func editor(text: Binding<String>, placeholder: String) -> some View {
        TextEditor(text: text)
            .font(.rounded(.body, weight: .medium))
            .scrollContentBackground(.hidden)
            .padding(10)
            .frame(minHeight: 200)
            .background(RoundedRectangle(cornerRadius: 14).fill(Palette.card))
            .overlay(alignment: .topLeading) {
                if text.wrappedValue.isEmpty && !placeholder.isEmpty {
                    Text(placeholder)
                        .font(.rounded(.body, weight: .medium))
                        .foregroundStyle(Palette.secondaryText.opacity(0.6))
                        .padding(18)
                        .allowsHitTesting(false)
                }
            }
    }

    private func wordCount(_ text: String, target: ClosedRange<Int>) -> some View {
        let count = words(in: text)
        return Text("\(count) / \(target.lowerBound)–\(target.upperBound) words")
            .font(.rounded(.caption, weight: .heavy))
            .foregroundStyle(target.contains(count) ? Palette.leaf : Palette.secondaryText)
            .contentTransition(.numericText())
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func comparison(_ title: String, _ text: String, _ color: Color) -> some View {
        RaisedCard(accent: color) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.rounded(.subheadline, weight: .heavy)).foregroundStyle(color)
                Text(text).font(.rounded(.body, weight: .medium)).foregroundStyle(Palette.ink)
            }
        }
    }

    private func words(in text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }

    /// The draft with each error highlighted in place.
    private func highlighted(_ text: String, _ corrections: [Correction]) -> AttributedString {
        var attributed = AttributedString(text)
        for correction in corrections {
            guard let range = Mistakes.range(of: correction.original, in: text),
                  let attributedRange = Range(range, in: attributed) else { continue }
            attributed[attributedRange].backgroundColor = Palette.coral.opacity(0.22)
            attributed[attributedRange].underlineStyle = .single
        }
        return attributed
    }

    private func check() async {
        errorMessage = nil
        stage = .checking
        do {
            feedback = try await CorrectionService.correct(draft, band: band, prompt: prompt)
            stage = .feedback
        } catch {
            errorMessage = error.localizedDescription
            stage = .writing
        }
    }
}

struct CorrectionRow: View {
    let correction: Correction

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(correction.original)
                    .strikethrough()
                    .foregroundStyle(Palette.coral)
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.secondaryText)
                Text(correction.corrected)
                    .foregroundStyle(Palette.leaf)
            }
            .font(.rounded(.headline, weight: .heavy))
            Text(correction.explanation)
                .font(.rounded(.subheadline, weight: .medium))
                .foregroundStyle(Palette.ink)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Palette.card))
    }
}
