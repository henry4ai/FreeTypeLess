import SwiftUI

struct QAResultView: View {
    @Environment(AppState.self) private var appState
    @State private var showCopied = false

    var body: some View {
        VStack(spacing: 0) {
            // Custom title bar — draggable
            HStack {
                Text("Q&A")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.accent)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Spacer()

                // Close button
                Button {
                    appState.showQAWindow = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.textTertiary)
                        .frame(width: 24, height: 24)
                        .background(Color.surfaceHover, in: RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.appBackground)

            // Separator
            Rectangle()
                .fill(Color.borderDefault)
                .frame(height: 1)

            // Body
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        // Context (optional)
                        if !appState.qaContext.isEmpty {
                            sectionLabel("Reference")
                            Text(appState.qaContext)
                                .font(.system(size: 13))
                                .foregroundColor(.textSecondary)
                                .lineSpacing(3)
                                .padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(maxHeight: 80)
                                .background(Color.purple.opacity(0.08))
                                .overlay(alignment: .leading) {
                                    Rectangle().fill(Color.purple).frame(width: 3)
                                }
                                .clipShape(.rect(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: 6, topTrailingRadius: 6))
                        }

                        // Question
                        if !appState.qaQuestion.isEmpty {
                            sectionLabel("Question")
                            Text(appState.qaQuestion)
                                .font(.system(size: 14))
                                .foregroundColor(.textPrimary)
                                .lineSpacing(4)
                        }

                        // Answer
                        sectionLabel("Answer")

                        if appState.qaHasError {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.error)
                                Text(appState.qaErrorMessage)
                                    .foregroundColor(.errorLight)
                            }
                            .font(.system(size: 14))
                        } else if appState.qaAnswer.isEmpty && !appState.qaIsDone {
                            HStack(spacing: 6) {
                                WaitingDots()
                                Text("Thinking...")
                                    .font(.system(size: 13))
                                    .foregroundColor(.textSecondary)
                            }
                            .padding(.vertical, 4)
                        } else {
                            MarkdownView(text: appState.qaAnswer)
                                .textSelection(.enabled)
                        }

                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .onChange(of: appState.qaAnswer) { _, _ in
                    withAnimation { proxy.scrollTo("bottom") }
                }
            }

            // Footer
            if appState.qaIsDone && !appState.qaAnswer.isEmpty {
                Rectangle()
                    .fill(Color.borderDefault)
                    .frame(height: 1)

                HStack {
                    Spacer()
                    Button {
                        OutputManager.copyToClipboard(appState.qaAnswer)
                        showCopied = true
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            showCopied = false
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 12))
                            Text(showCopied ? "Copied!" : "Copy Answer")
                                .font(.system(size: 13))
                        }
                        .foregroundColor(.accentLight)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.processingBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
        .background(Color.appBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.processingBorder, lineWidth: 1))
        .onKeyPress(.escape) {
            appState.showQAWindow = false
            return .handled
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundColor(.textTertiary)
            .textCase(.uppercase)
            .padding(.bottom, -8) // tighten gap to content below
    }
}

// MARK: - Waiting Dots

private struct WaitingDots: View {
    @State private var phase: Int = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.accent)
                    .frame(width: 6, height: 6)
                    .scaleEffect(i == phase ? 1.2 : 0.8)
                    .opacity(i == phase ? 1.0 : 0.3)
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    phase = (phase + 1) % 3
                }
            }
        }
    }
}
