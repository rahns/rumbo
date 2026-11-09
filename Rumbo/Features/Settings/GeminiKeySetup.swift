import RumboCore
import SwiftUI
import UIKit

/// The free Gemini key setup, as onboarding shows it.
struct GeminiKeySetup: View {
    @Binding var key: String

    var body: some View { AIKeySetup(provider: .gemini, key: $key) }
}

/// How to get an API key for a provider, a field to paste it and a test. Used in onboarding and in Settings.
struct AIKeySetup: View {
    let provider: WritingModel.Provider
    @Binding var key: String

    @State private var testing = false
    @State private var testResult: String?
    @State private var testPassed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            RaisedCard(accent: Palette.sky) {
                VStack(alignment: .leading, spacing: 12) {
                    if provider == .gemini {
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
                    } else {
                        Text("Get a Claude API key")
                            .font(.rounded(.headline, weight: .black))
                            .foregroundStyle(Palette.ink)
                        step(1, "Open the Claude Console and sign in, or create an account.")
                        Link(destination: Claude.keyPage) {
                            Label("Open the Claude Console", systemImage: "arrow.up.right.square.fill")
                        }
                        .buttonStyle(ChunkySecondaryButtonStyle())
                        step(2, "Under **Billing**, add some credit. $5 covers thousands of checks with Haiku.")
                        step(3, "Under **API keys**, tap **Create key**, give it a name and copy it. It's only shown once.")
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
                if provider == .gemini {
                    note("gift.fill", "Free: Google gives a daily allowance, plenty for a few writing checks a day. If you run out, Rumbo uses its basic checker and shows a small warning.")
                    note("eye.fill", "On the free tier Google may use what you send to improve its products, so don't write anything private.")
                } else {
                    note("creditcard.fill", "Paid: each check is billed to your Anthropic account, roughly 0.1¢ with Haiku, 3¢ with Sonnet and 5¢ with Opus at medium thinking. You can set a spending limit in the Console.")
                }
                note("lock.fill", "Your key is kept in the phone's Keychain and saved in your backups, so restoring brings it back. Keep backup files private.")
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
        // The chosen model if it's this provider's, otherwise the provider's cheapest.
        let chosen = AISettings.model
        let model = chosen.provider == provider ? chosen : (provider == .gemini ? .geminiFlashLite : .claudeHaiku)
        let result = await AIClient.test(model: model, key: key.trimmingCharacters(in: .whitespacesAndNewlines))
        testPassed = result.works
        testResult = result.message
    }
}

/// Settings → Writing feedback: which model checks writing, its key, and how hard it thinks.
struct GeminiSettingsView: View {
    /// Called after any change, so the Settings row can update.
    var onChange: () -> Void = {}

    @State private var model = AISettings.model
    @State private var keys: [WritingModel.Provider: String] = Dictionary(uniqueKeysWithValues:
        WritingModel.Provider.allCases.map { ($0, AISettings.key(for: $0) ?? "") })
    @State private var thinking = AISettings.thinkingLevel

    private var thinkingNote: String {
        switch thinking {
        case .low: "Quickest. Catches the basics; may miss subtler tense or naturalness errors."
        case .medium: "Recommended. A careful check in a few seconds."
        case .high: model.provider == .gemini
            ? "Most thorough, for longer or harder texts. Checks take longer and may use more of the free allowance."
            : "Most thorough, for longer or harder texts. Checks take longer and cost more."
        }
    }

    private func detail(_ option: WritingModel) -> String {
        switch option {
        case .geminiFlashLite: "Free with a Google key · quick · recommended"
        case .geminiFlash: "Free with a Google key · often busy"
        case .claudeHaiku: "Paid, Anthropic key · about 0.1¢ a check · quick"
        case .claudeSonnet: "Paid, Anthropic key · about 3¢ a check"
        case .claudeOpus: "Paid, Anthropic key · about 5¢ a check · most thorough"
        }
    }

    private var key: Binding<String> {
        Binding(get: { keys[model.provider] ?? "" }, set: { keys[model.provider] = $0 })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Pico checks your writing with the AI model you choose, using your own API key. Without one, Rumbo uses its basic checker (LanguageTool and the on-device model), which misses more.")
                    .font(.rounded(.subheadline, weight: .medium))
                    .foregroundStyle(Palette.secondaryText)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Model")
                        .font(.rounded(.headline, weight: .black))
                        .foregroundStyle(Palette.ink)
                    VStack(spacing: 0) {
                        ForEach(WritingModel.allCases, id: \.self) { option in
                            Button {
                                model = option
                            } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(option.displayName)
                                            .font(.rounded(.body, weight: .bold))
                                            .foregroundStyle(Palette.ink)
                                        Text(detail(option))
                                            .font(.rounded(.caption, weight: .semibold))
                                            .foregroundStyle(Palette.secondaryText)
                                    }
                                    Spacer()
                                    Image(systemName: model == option ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(model == option ? Palette.leaf : Palette.secondaryText.opacity(0.5))
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 14)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if option != WritingModel.allCases.last { Divider().padding(.leading, 14) }
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 16).fill(Palette.card))
                    .sensoryFeedback(.selection, trigger: model)
                }
                AIKeySetup(provider: model.provider, key: key)
                    .id(model.provider)
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
                if !(keys[model.provider] ?? "").isEmpty {
                    Button("Remove \(model.provider.name) key", role: .destructive) {
                        keys[model.provider] = ""
                    }
                    .buttonStyle(ChunkySecondaryButtonStyle())
                }
            }
            .padding(20)
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle("Writing feedback")
        .navigationBarTitleDisplayMode(.inline)
        // Everything is saved as it changes; an empty key field removes that key.
        .onChange(of: model) { _, new in AISettings.model = new; onChange() }
        .onChange(of: thinking) { _, new in AISettings.thinkingLevel = new }
        .onChange(of: keys) { _, new in
            for (provider, key) in new { AISettings.save(key, for: provider) }
            onChange()
        }
    }
}
