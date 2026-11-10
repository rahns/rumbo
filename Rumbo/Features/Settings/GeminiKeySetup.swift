import RumboCore
import SwiftUI
import UIKit

/// How to get a free Gemini API key, a field to paste it and a test. Used in onboarding and in Settings.
struct GeminiKeySetup: View {
    @Binding var key: String
    /// Shows the setup for the free Groq key (the backup checker) instead of Gemini's.
    var groq = false

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
                    if groq {
                        step(1, "Open the GroqCloud console (Groq with a Q, not Grok) and sign up with an email or Google account.")
                        Link(destination: Groq.keyPage) {
                            Label("Open GroqCloud", systemImage: "arrow.up.right.square.fill")
                        }
                        .buttonStyle(ChunkySecondaryButtonStyle())
                        step(2, "Tap **Create API Key** and give it any name. The free plan needs no card.")
                        step(3, "Copy the key. It's only shown once.")
                        step(4, "Come back here and tap **Paste**.")
                    } else {
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
                note("gift.fill", groq
                     ? "Free: GroqCloud gives about 1,000 requests a day, plenty for writing checks."
                     : "Free: Google gives a daily allowance, plenty for a few writing checks a day. If you run out, Rumbo tries GroqCloud (if set up), then its basic checker, and shows a small warning.")
                note("lock.fill", "Your key is kept in the phone's Keychain and saved in your backups, so restoring brings it back. Keep backup files private.")
                if !groq {
                    note("eye.fill", "On the free tier Google may use what you send to improve its products, so don't write anything private.")
                }
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
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let result: (works: Bool, message: String)
        if groq {
            result = await GroqClient.test(key: trimmed)
        } else {
            result = await GeminiClient.test(key: trimmed)
        }
        testPassed = result.works
        testResult = result.message
    }
}

/// Settings → Writing feedback: which checker goes first, each checker's free key, and how hard they think.
struct GeminiSettingsView: View {
    private var thinkingNote: String {
        switch thinking {
        case .low: "Quickest. Catches the basics; may miss subtler tense or naturalness errors."
        case .medium: "Recommended. A careful check in a few seconds."
        case .high: "Most thorough, for longer or harder texts. Checks take longer and may use more of the free allowance."
        }
    }

    /// Called after any change, so the Settings row can update.
    var onChange: (Bool) -> Void = { _ in }

    @State private var key = GeminiKey.current ?? ""
    @State private var groqKey = GroqKey.current ?? ""
    @State private var thinking = GeminiKey.thinkingLevel
    @State private var defaultChecker = WritingCheckers.defaultChecker

    private var orderNote: String {
        var available: Set<WritingChecker> = []
        if !key.isEmpty { available.insert(.gemini) }
        if !groqKey.isEmpty { available.insert(.groq) }
        let order = WritingChecker.order(default: defaultChecker, available: available)
        switch order.count {
        case 0: return "No keys yet: the basic checker (LanguageTool and the on-device model) checks your writing. It misses more."
        case 1 where order[0] != defaultChecker:
            return "\(defaultChecker.name) has no key yet, so \(order[0].name) checks your writing, then the basic checker if it can't."
        case 1: return "\(order[0].name) checks your writing. Add a \(order[0] == .gemini ? "Groq" : "Gemini") key too, and it's tried when \(order[0].name) can't answer."
        default: return "\(order[0].name) checks your writing first. If it can't answer, \(order[1].name) does, then the basic checker."
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Pico checks your writing with free AI checkers, using your own free API keys. Set up one or both.")
                    .font(.rounded(.subheadline, weight: .medium))
                    .foregroundStyle(Palette.secondaryText)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Default checker")
                        .font(.rounded(.headline, weight: .black))
                        .foregroundStyle(Palette.ink)
                    Picker("Default checker", selection: $defaultChecker) {
                        Text("Gemini Flash-Lite").tag(WritingChecker.gemini)
                        Text("GroqCloud").tag(WritingChecker.groq)
                    }
                    .pickerStyle(.segmented)
                    Label(orderNote, systemImage: "arrow.triangle.branch")
                        .font(.rounded(.caption, weight: .semibold))
                        .foregroundStyle(Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
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
                section("Gemini Flash-Lite", "Google's free model: quick, and plenty for checking short texts.")
                GeminiKeySetup(key: $key)
                if !key.isEmpty {
                    Button("Remove Gemini key", role: .destructive) { key = "" }
                        .buttonStyle(ChunkySecondaryButtonStyle())
                }
                section("GroqCloud", "Groq with a Q, at console.groq.com: a company that runs open AI models fast. Not Grok, the chatbot on X. Also free, and usually less busy than Google. Rumbo picks the best model GroqCloud offers (GPT-OSS 120B for now) and switches by itself if GroqCloud changes its models.")
                GeminiKeySetup(key: $groqKey, groq: true)
                if !groqKey.isEmpty {
                    Button("Remove GroqCloud key", role: .destructive) { groqKey = "" }
                        .buttonStyle(ChunkySecondaryButtonStyle())
                }
            }
            .padding(20)
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle("Writing feedback")
        .navigationBarTitleDisplayMode(.inline)
        // Everything is saved as it changes; an empty key field removes that key.
        .onChange(of: thinking) { _, new in GeminiKey.thinkingLevel = new }
        .onChange(of: defaultChecker) { _, new in
            WritingCheckers.defaultChecker = new
            onChange(true)
        }
        .onChange(of: groqKey) { _, new in
            GroqKey.save(new)
            onChange(true)
        }
        .onChange(of: key) { _, new in
            GeminiKey.save(new)
            onChange(true)
        }
    }

    private func section(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.rounded(.title3, weight: .black))
                .foregroundStyle(Palette.ink)
            Text(detail)
                .font(.rounded(.subheadline, weight: .medium))
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 10)
    }
}
