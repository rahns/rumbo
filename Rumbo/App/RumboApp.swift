import RumboCore
import SwiftUI

@main
struct RumboApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Milestone 0 placeholder home screen. The real path arrives in M3.
struct RootView: View {
    @State private var hover = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "bird.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.tint)
                    .offset(y: hover ? -8 : 8)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: hover)
                    .onAppear { hover = true }
                VStack(spacing: 8) {
                    Text("¿Rumbo a dónde?")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("Milestone 0 test build. Run diagnostics and send the report back so the real app can be built on what your phone supports.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                NavigationLink {
                    DiagnosticsView()
                } label: {
                    Text("Run diagnostics")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                Text("Starting band for 154 h: \(Band.forInputHours(154).label)")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .padding(24)
        }
    }
}
