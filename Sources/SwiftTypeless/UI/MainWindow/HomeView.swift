import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @State private var navigateToSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Drag region / title bar (48px)
                    HStack {
                        Spacer()
                        Button {
                            NSApp.windows.first?.miniaturize(nil)
                        } label: {
                            Image(systemName: "minus")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.textTertiary)
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 16)
                    }
                    .frame(height: 48)

                    // Content
                    VStack(spacing: 0) {
                        // Logo area
                        VStack(spacing: 8) {
                            // Logo icon
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.accent)
                                    .frame(width: 48, height: 48)
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white)
                            }

                            Text("FreeTypeless")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)

                            Text("Type without typing")
                                .font(.system(size: 13))
                                .foregroundColor(.textHint)
                        }
                        .padding(.bottom, 24)

                        // Status card
                        statusCard
                            .padding(.bottom, 28)

                        // Shortcuts
                        shortcutsSection
                            .padding(.bottom, 28)

                        Spacer()

                        // Settings button
                        Button {
                            navigateToSettings = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "gearshape")
                                    .font(.system(size: 14))
                                Text("Settings")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(.textSecondary)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Color.surfaceLight, in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderMedium, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                }
            }
            .navigationDestination(isPresented: $navigateToSettings) {
                SettingsView()
                    .environment(appState)
            }
        }
    }

    // MARK: - Status Card

    @ViewBuilder
    private var statusCard: some View {
        switch appState.status {
        case .ready:
            readyCard
        case .recording(let mode):
            recordingCard(mode: mode)
        case .processing:
            processingCard
        case .result(let text):
            resultCard(text: text)
        case .error(let message):
            errorCard(message: message)
        }
    }

    private var readyCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                // Green status dot with glow
                Circle()
                    .fill(Color.success)
                    .frame(width: 8, height: 8)
                    .shadow(color: Color.success.opacity(0.4), radius: 3)

                Text("READY")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.textSecondary)
                    .textCase(.uppercase)

                Spacer()
            }

            // Model info
            if SettingsStore.shared.isConfigured {
                Text(SettingsStore.shared.modelDescription)
                    .font(.system(size: 11))
                    .foregroundColor(.warning)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.modelInfoBg, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.modelInfoBorder, lineWidth: 1))
            } else {
                Button {
                    navigateToSettings = true
                } label: {
                    Text("No model configured — click to setup")
                        .font(.system(size: 11))
                        .foregroundColor(.warning)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.modelInfoBg, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.modelInfoBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.borderDefault, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderDefault, lineWidth: 1))
    }

    private func recordingCard(mode: RecordingMode) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.error)
                    .frame(width: 8, height: 8)

                Text(modeName(mode))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.error)

                Spacer()
            }

            RecordingIndicator(level: appState.audioLevel)
                .frame(height: 20)

            if !appState.interimText.isEmpty {
                ScrollView {
                    Text(appState.interimText)
                        .font(.system(size: 14))
                        .foregroundColor(.textSecondary)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 80)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.recordingBg, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.recordingBorder, lineWidth: 1))
    }

    private var processingCard: some View {
        HStack(spacing: 10) {
            // Spinner
            ProgressView()
                .controlSize(.small)
                .tint(.accent)

            Text("Processing...")
                .font(.system(size: 13))
                .foregroundColor(.textSecondary)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.processingBg, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.processingBorder, lineWidth: 1))
    }

    private func resultCard(text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.success)
                Text("Copied & Pasted")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.success)
                Spacer()
            }

            ScrollView {
                Text(text)
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 120)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color.processingBg, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.processingBorder, lineWidth: 1))
    }

    private func errorCard(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundColor(.error)
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.errorLight)
                .lineLimit(3)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.error.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.error.opacity(0.3), lineWidth: 1))
    }

    private func modeName(_ mode: RecordingMode) -> String {
        switch mode {
        case .transcribe: return "Recording"
        case .translate: return "Recording — Translate"
        case .qa: return "Recording — Q&A"
        }
    }

    // MARK: - Shortcuts

    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("KEYBOARD SHORTCUTS")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.sectionHeading)
                .textCase(.uppercase)
                .padding(.bottom, 4)

            shortcutRow(icon: "mic.fill", keys: ["⌥"], label: "Voice to Text")
            shortcutRow(icon: "globe", keys: ["⌥", "⇧"], label: "Translate")
            shortcutRow(icon: "questionmark.circle", keys: ["⌥", "Space"], label: "Q&A")
        }
    }

    private func shortcutRow(icon: String, keys: [String], label: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.accent)
                .frame(width: 20)

            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.textPrimary)

            Spacer()

            HStack(spacing: 4) {
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.surfaceLight, in: RoundedRectangle(cornerRadius: 5))
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.borderStrong, lineWidth: 1))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.borderDefault, in: RoundedRectangle(cornerRadius: 10))
    }
}
