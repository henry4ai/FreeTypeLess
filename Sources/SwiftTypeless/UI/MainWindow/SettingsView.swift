import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    private let settings = SettingsStore.shared
    @State private var showSaved = false

    // Local edit state
    @State private var provider: Provider = .bailian
    @State private var bailianApiKey = ""
    @State private var bailianBaseUrl = ""
    @State private var bailianModel = ""
    @State private var bailianPromptAsr = ""
    @State private var bailianPromptTranslation = ""
    @State private var bailianPromptQa = ""
    @State private var openRouterApiKey = ""
    @State private var openRouterModel = ""
    @State private var orPromptAsr = ""
    @State private var orPromptTranslation = ""
    @State private var orPromptQa = ""
    @State private var targetLanguage = "English"
    @State private var autoStart = false

    @State private var bailianModels: [String] = []
    @State private var openRouterModels: [OpenRouterProvider.ModelInfo] = []
    @State private var isLoadingModels = false

    // Resizable prompt heights
    @State private var promptHeights: [String: CGFloat] = [:]

    private let languages = ["English", "Chinese", "Japanese", "Korean", "French", "German", "Spanish", "Portuguese", "Russian", "Arabic"]

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header: Back + Title — sits right below the traffic lights drag area
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 14))
                        }
                        .foregroundColor(.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.2), lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text("Settings")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()
                    Color.clear.frame(width: 70, height: 1)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                // Scrollable settings body
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        // -- Provider Mode --
                        settingsSection("Provider Mode") {
                            HStack(spacing: 0) {
                                Text("Provider")
                                    .font(.system(size: 13))
                                    .foregroundColor(.textLabel)
                                    .frame(width: 70, alignment: .leading)
                                Picker("", selection: $provider) {
                                    ForEach(Provider.allCases, id: \.self) { p in
                                        Text(p.displayName).tag(p)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(maxWidth: 280)
                            }
                        }

                        // -- Bailian / OpenRouter --
                        if provider == .bailian {
                            bailianSection
                        } else {
                            openRouterSection
                        }

                        // -- General --
                        settingsSection("General") {
                            formField("Target Language") {
                                Picker("", selection: $targetLanguage) {
                                    ForEach(languages, id: \.self) { l in Text(l).tag(l) }
                                }
                                .labelsHidden()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            HStack {
                                Toggle("", isOn: $autoStart)
                                    .labelsHidden()
                                    .toggleStyle(.switch)
                                Text("Launch at startup")
                                    .font(.system(size: 14))
                                    .foregroundColor(.textPrimary)
                            }
                        }

                        // -- Save --
                        VStack(spacing: 8) {
                            Rectangle()
                                .fill(Color.borderDefault)
                                .frame(height: 1)

                            HStack {
                                Spacer()
                                Button {
                                    saveSettings()
                                } label: {
                                    Text("Save Settings")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 10)
                                        .background(Color.accent, in: RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)

                                if showSaved {
                                    Text("Settings saved!")
                                        .font(.system(size: 13))
                                        .foregroundColor(.success)
                                        .transition(.opacity)
                                }
                                Spacer()
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: 600)
                    .frame(maxWidth: .infinity) // center the 600px block
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear { loadSettings() }
    }

    // MARK: - Section Helper

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header with bottom border
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.sectionHeading)
                    .textCase(.uppercase)
                    .padding(.bottom, 8)
                Rectangle()
                    .fill(Color.borderDefault)
                    .frame(height: 1)
            }

            content()
        }
    }

    // MARK: - Bailian

    private var bailianSection: some View {
        settingsSection("Aliyun Bailian") {
            formField("API Key") {
                SecureField("Enter Bailian API Key", text: $bailianApiKey)
                    .styledInput()
                    .onChange(of: bailianApiKey) { _, v in if v.count >= 10 { fetchBailianModels() } }
            }

            formField("Base URL") {
                TextField("Base URL", text: $bailianBaseUrl)
                    .styledInput()
            }

            formField("LLM Model") {
                if bailianModels.isEmpty {
                    TextField("Model name (e.g. qwen3.5-plus)", text: $bailianModel)
                        .styledInput()
                } else {
                    Picker("", selection: $bailianModel) {
                        ForEach(bailianModels, id: \.self) { m in Text(m).tag(m) }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            promptsGroup(
                asr: $bailianPromptAsr,
                translation: $bailianPromptTranslation,
                qa: $bailianPromptQa
            )
        }
    }

    // MARK: - OpenRouter

    private var openRouterSection: some View {
        settingsSection("OpenRouter") {
            formField("API Key") {
                SecureField("Enter OpenRouter API Key", text: $openRouterApiKey)
                    .styledInput()
                    .onChange(of: openRouterApiKey) { _, v in if v.count >= 10 { fetchOpenRouterModels() } }
            }

            formField("Model") {
                if openRouterModels.isEmpty {
                    TextField("Model ID", text: $openRouterModel)
                        .styledInput()
                } else {
                    Picker("", selection: $openRouterModel) {
                        ForEach(openRouterModels) { m in Text(m.name).tag(m.id) }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            promptsGroup(
                asr: $orPromptAsr,
                translation: $orPromptTranslation,
                qa: $orPromptQa
            )
        }
    }

    // MARK: - Prompts Group

    private func promptsGroup(asr: Binding<String>, translation: Binding<String>, qa: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prompts")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.textSecondary)
                .padding(.top, 4)

            promptArea("ASR Prompt", text: asr)
            promptArea("Translation Prompt", text: translation)
            promptArea("Q&A Prompt", text: qa)
        }
    }

    // MARK: - Form Helpers

    private func formField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.textLabel)
            content()
        }
    }

    private func promptArea(_ label: String, text: Binding<String>) -> some View {
        let height = promptHeights[label] ?? 80

        return VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.textTertiary)
            VStack(spacing: 0) {
                TextEditor(text: text)
                    .font(.system(size: 13, design: .monospaced))
                    .lineSpacing(4)
                    .scrollContentBackground(.hidden)
                    .foregroundColor(.textPrimary)
                    .padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    .frame(height: height)

                // Drag handle
                HStack {
                    Spacer()
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 8))
                        .foregroundColor(.textTertiary)
                    Spacer()
                }
                .frame(height: 12)
                .contentShape(Rectangle())
                .onHover { inside in
                    if inside {
                        NSCursor.resizeUpDown.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            let newHeight = max(60, height + value.translation.height)
                            promptHeights[label] = newHeight
                        }
                )
            }
            .background(Color.surfaceLight, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderStrong, lineWidth: 1))
        }
    }

    // MARK: - Load / Save

    private func loadSettings() {
        let s = settings
        provider = s.provider
        bailianApiKey = s.bailianApiKey
        bailianBaseUrl = s.bailianBaseUrl
        bailianModel = s.bailianModel
        bailianPromptAsr = s.bailianPromptAsr
        bailianPromptTranslation = s.bailianPromptTranslation
        bailianPromptQa = s.bailianPromptQa
        openRouterApiKey = s.openRouterApiKey
        openRouterModel = s.openRouterModel
        orPromptAsr = s.orPromptAsr
        orPromptTranslation = s.orPromptTranslation
        orPromptQa = s.orPromptQa
        targetLanguage = s.targetLanguage
        autoStart = s.autoStart

        // Auto-fetch models if API keys are already present
        if bailianApiKey.count >= 10 { fetchBailianModels() }
        if openRouterApiKey.count >= 10 { fetchOpenRouterModels() }
    }

    private func saveSettings() {
        let s = settings
        s.provider = provider
        s.bailianApiKey = bailianApiKey
        s.bailianBaseUrl = bailianBaseUrl
        s.bailianModel = bailianModel
        s.bailianPromptAsr = bailianPromptAsr
        s.bailianPromptTranslation = bailianPromptTranslation
        s.bailianPromptQa = bailianPromptQa
        s.openRouterApiKey = openRouterApiKey
        s.openRouterModel = openRouterModel
        s.orPromptAsr = orPromptAsr
        s.orPromptTranslation = orPromptTranslation
        s.orPromptQa = orPromptQa
        s.targetLanguage = targetLanguage
        s.autoStart = autoStart

        withAnimation { showSaved = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { showSaved = false }
        }
    }

    private func fetchBailianModels() {
        guard !isLoadingModels else { return }
        isLoadingModels = true
        Task {
            defer { isLoadingModels = false }
            do {
                var request = URLRequest(url: URL(string: "\(bailianBaseUrl)/models")!)
                request.setValue("Bearer \(bailianApiKey)", forHTTPHeaderField: "Authorization")
                request.timeoutInterval = 15
                let (data, _) = try await URLSession.shared.data(for: request)
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let models = json["data"] as? [[String: Any]] else { return }
                let qwen = models.compactMap { m -> String? in
                    guard let id = m["id"] as? String, id.lowercased().contains("qwen") else { return nil }
                    return id
                }.sorted()
                await MainActor.run {
                    bailianModels = qwen
                    if !qwen.isEmpty && !qwen.contains(bailianModel) { bailianModel = qwen.first ?? bailianModel }
                }
            } catch { print("[Settings] Bailian models error: \(error)") }
        }
    }

    private func fetchOpenRouterModels() {
        guard !isLoadingModels else { return }
        isLoadingModels = true
        Task {
            defer { isLoadingModels = false }
            do {
                let models = try await OpenRouterProvider.fetchModels(apiKey: openRouterApiKey)
                await MainActor.run {
                    openRouterModels = models
                    if !models.isEmpty && !models.contains(where: { $0.id == openRouterModel }) {
                        openRouterModel = models.first?.id ?? openRouterModel
                    }
                }
            } catch { print("[Settings] OpenRouter models error: \(error)") }
        }
    }
}

// MARK: - Styled Input Modifier

private extension View {
    func styledInput() -> some View {
        self
            .textFieldStyle(.plain)
            .foregroundColor(.textPrimary)
            .padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            .background(Color.surfaceLight, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderStrong, lineWidth: 1))
    }
}
