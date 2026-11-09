import RumboCore
import SwiftUI
import UIKit

/// How to get a free Gemini API key, a field to paste it and a test. Used in onboarding and in Settings.
struct GeminiKeySetup: View {
    @Binding var key: String

    @State private var testing = false
    @State private var testResult: String?
    @State private var testPassed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            RaisedCard(accent: Palette.sky) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Get a free key in 2 minutes")
                        .font(.rounded(.headline, weight: .black))
                        .foregroundStyle(Palette.ink)
                    step(1, "Open Google AI Studio and sign in with any Google account.")
                    Link(destination: Gemini.keyPage) {
                        Label("Open Google AI Studio", systemImage: "arrow.up.right.square.fill")
                    }
                    .buttonStyle(ChunkySecondaryButtonStyle())
                    step(2, "Tap **Create API key**. If it asks for a project, pick the default one. No card or billing needed.")
                    step(3, "Tap the copy button next to your new key.")
                    step(4, "Come back here and tap **Paste**.")
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    TextField("Paste your API key", text: $key)
                        .font(.system(.subheadline, design: .monospaced))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.card))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.lilac, lineWidth: 2))
                    Button("Paste") {
                        if let text = UIPasteboard.general.string { key = text.trimmingCharacters(in: .whitespacesAndNewlines) }
                    }
                    .buttonStyle(ChunkySecondaryButtonStyle(fullWidth: false))
                }
                if !key.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button {
                        Task { await test() }
                    } label: {
                        if testing {
                            ProgressView()
                        } else {
                            Label("Test the key", systemImage: "checkmark.seal.fill")
                        }
                    }
                    .buttonStyle(ChunkySecondaryButtonStyle())
                    .disabled(testing)
                }
                if let testResult {
                    Label(testResult, systemImage: testPassed ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.rounded(.subheadline, weight: .semibold))
                        .foregroundStyle(testPassed ? Palette.leaf : Palette.coral)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .onChange(of: key) { testResult = nil }

            VStack(alignment: .leading, spacing: 6) {
                note("gift.fill", "Free: Google gives a daily allowance, plenty for a few writing checks a day. If you run out, Rumbo uses its basic checker and shows a small warning.")
                note("lock.fill", "Your key is kept in the phone's Keychain and saved in your backups, so restoring brings it back. Keep backup files private.")
                note("eye.fill", "On the free tier Google may use what you send to improve its products, so don't write anything private.")
            }
        }
    }

    private func step(_ number: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number)")
                .font(.rounded(.subheadline, weight: .black))
                .foregroundStyle(Palette.inkOnBright)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Palette.sky))
            Text(text)
                .font(.rounded(.subheadline, weight: .medium))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func note(_ symbol: String, _ text: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.rounded(.caption, weight: .semibold))
            .foregroundStyle(Palette.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func test() async {
        testing = true
        defer { testing = false }
        let result = await GeminiClient.test(key: key.trimmingCharacters(in: .whitespacesAndNewlines))
        testPassed = result.works
        testResult = result.message
    }
}

/// Settings → Writing feedback.
struct GeminiSettingsView: View {
    private var thinkingNote: String {
        switch thinking {
        case .low: "Quickest. Catches the basics; may miss subtler tense or naturalness errors."
        case .medium: "Recommended. A careful check in a few seconds."
        case .high: "Most thorough, for longer or harder texts. Checks take longer and may use more of the free allowance."
        }
    }

    /// Told whether a key is saved, so the Settings row can update.
    var onChange: (Bool) -> Void = { _ in }

    @State private var key = GeminiKey.current ?? ""
    @State private var thinking = GeminiKey.thinkingLevel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Pico checks your writing with Google's Gemini, using your own free API key. Without one, Rumbo uses its basic checker (LanguageTool and the on-device model), which misses more.")
                    .font(.rounded(.subheadline, weight: .medium))
                    .foregroundStyle(Palette.secondaryText)
                GeminiKeySetup(key: $key)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Thinking")
                        .font(.rounded(.headline, weight: .black))
                        .foregroundStyle(Palette.ink)
                    Picker("Thinking", selection: $thinking) {
                        Text("Low").tag(Gemini.ThinkingLevel.low)
                        Text("Medium").tag(Gemini.ThinkingLevel.medium)
                        Text("High").tag(Gemini.ThinkingLevel.high)
                    }
                    .pickerStyle(.segmented)
                    Label(thinkingNote, systemImage: "info.circle")
                        .font(.rounded(.caption, weight: .semibold))
                        .foregroundStyle(Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if GeminiKey.current != nil {
                    Button("Remove key", role: .destructive) {
                        GeminiKey.remove()
                        key = ""
                    }
                    .buttonStyle(ChunkySecondaryButtonStyle())
                }
            }
            .padding(20)
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle("Writing feedback")
        .navigationBarTitleDisplayMode(.inline)
        // Saved as it's typed or pasted; an empty field removes the key.
        .onChange(of: thinking) { _, new in GeminiKey.thinkingLevel = new }
        .onChange(of: key) { _, new in
            GeminiKey.save(new)
            onChange(GeminiKey.current != nil)
        }
    }
}
