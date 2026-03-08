import SwiftUI

struct OverlayPanel: View {
    @Environment(AppState.self) private var appState

    private let panelHeight: CGFloat = 36
    private let radius: CGFloat = 18

    var body: some View {
        Group {
            switch appState.status {
            case .recording(let mode):
                recordingView(mode: mode)
            case .processing:
                processingView
            case .error(let message):
                errorView(message: message)
            case .result:
                resultView
            default:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Pill background

    private func pill<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(Color.surfaceDark)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius)
                            .stroke(Color.borderDefault, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 5, y: 2)
            )
    }

    // MARK: - Recording

    private func recordingView(mode: RecordingMode) -> some View {
        VStack(spacing: 6) {
            // Text label pill (translate / QA only)
            if mode != .transcribe {
                pill {
                    Text(modeLabel(mode))
                        .font(.system(size: 12))
                        .foregroundColor(.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
            }

            // Waveform pill
            pill {
                RecordingIndicator(level: appState.audioLevel)
                    .frame(height: 24)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 6)
                    .frame(width: 100, height: panelHeight)
            }
        }
    }

    private func modeLabel(_ mode: RecordingMode) -> String {
        let settings = SettingsStore.shared
        switch mode {
        case .transcribe: return "Listening..."
        case .translate: return "Translating → \(settings.targetLanguage)"
        case .qa: return "Asking question..."
        }
    }

    // MARK: - Processing

    private var processingView: some View {
        pill {
            Text("Processing")
                .font(.system(size: 11))
                .foregroundColor(.textSecondary)
                .frame(width: 100, height: panelHeight)
                .background(alignment: .leading) {
                    GeometryReader { geo in
                        Color.white.opacity(0.08)
                            .frame(width: geo.size.width * appState.processingProgress)
                            .clipShape(RoundedRectangle(cornerRadius: radius))
                            .animation(.easeInOut(duration: 0.5), value: appState.processingProgress)
                    }
                }
        }
    }

    // MARK: - Error

    private func errorView(message: String) -> some View {
        pill {
            HStack(spacing: 5) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.error)
                    .font(.system(size: 10))
                Text(message)
                    .font(.system(size: 10))
                    .foregroundColor(.errorLight)
                    .lineLimit(2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .frame(width: 180, height: 44)
        }
    }

    // MARK: - Result

    private var resultView: some View {
        pill {
            HStack(spacing: 5) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.success)
                    .font(.system(size: 10))
                Text("Pasted")
                    .font(.system(size: 10))
                    .foregroundColor(.textSecondary)
            }
            .frame(width: 100, height: panelHeight)
        }
    }
}
