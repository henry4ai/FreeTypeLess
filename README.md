# FreeTypeless

> Type without typing — a macOS voice input app with real-time transcription, translation, and Q&A.

FreeTypeless lets you input text anywhere on macOS by simply holding a hotkey and speaking. It captures your voice, transcribes it via streaming ASR, polishes the text with an LLM, and auto-pastes the result — all in under a second.

## Features
![final](./Resources/imgs/final.png)
- **Voice to Text** — Hold `Option` to record, release to transcribe and auto-paste
- **Translation** — `Option + Shift` to transcribe and translate into your target language
- **Q&A** — `Option + Space` to ask a question; optionally select text first for context
- **Streaming** — Real-time ASR preview while recording, streaming LLM responses
- **Dual Provider** — Aliyun Bailian (with DashScope ASR) or OpenRouter (audio multimodal)
- **Markdown Rendering** — Q&A answers rendered with full Markdown support
- **Works Everywhere** — Global hotkeys and auto-paste work across all applications

## Why Native Swift

FreeTypeless is written in pure Swift and SwiftUI, with no Electron or cross‑platform runtime bundled in.

- **Tiny install size** — the signed `.app` is around **2 MB** once installed, with no extra frameworks or runtimes to download.
- **High performance** — native Swift code starts up almost instantly and keeps end‑to‑end latency (from pressing `⌥` to text appearing) extremely low.
- **Low resource usage** — compared with apps built using web engines, FreeTypeless uses less memory and CPU, so it stays quiet in the background.
- **Deep macOS integration** — built directly on Apple frameworks (SwiftUI, AVFoundation, AppKit, CoreGraphics), so global hotkeys, accessibility, and pasteboard integration are smooth and reliable.

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌥` (hold) | Voice to text |
| `⌥` + `⇧` | Voice to translation |
| `⌥` + `Space` | Voice Q&A |
| Release `⌥` | Stop recording & process |
| `Esc` | Cancel |

**Tip:** In Q&A mode, select text in any app before pressing `⌥` — the selected text becomes context for your question.

## Requirements

- macOS 14.0+
- Microphone permission
- Accessibility permission (for global hotkeys and auto-paste)
- An API key for at least one provider:
  - [Aliyun Bailian](https://bailian.console.aliyun.com/) (DashScope)
  - [OpenRouter](https://openrouter.ai/)

## Installation

### From DMG

Download the latest `.dmg` from [Releases](../../releases), open it, and drag **FreeTypeless** to Applications.

### Build from Source

```bash
git clone https://github.com/anthropics/FreeTypeless.git
cd FreeTypeless

# Run in development mode
swift run

# Or build a signed DMG installer
./build-dmg.sh
# Output: dist/FreeTypeless.app and dist/FreeTypeless.dmg
```

## Configuration

On first launch, click **Settings** to configure your provider:

**Aliyun Bailian:**
- API Key — your DashScope API key
- Base URL — defaults to `https://dashscope.aliyuncs.com/compatible-mode/v1`
- LLM Model — defaults to `qwen3.5-plus` (auto-fetches available models)

**OpenRouter:**
- API Key — your OpenRouter API key
- Model — defaults to `google/gemini-2.5-flash` (auto-fetches audio-capable models)

Each provider has customizable system prompts for transcription polishing, translation, and Q&A.

You can also create a `.env` file in the project root:

```
ALIYUN_API_KEY=sk-...
OPENROUTER_API_KEY=sk-or-v1-...
```

## How It Works

```
Hold ⌥ ──► Microphone captures audio (16kHz PCM)
           │
           ├─ Bailian mode: streams audio to Aliyun ASR via WebSocket
           │                 interim results shown in real-time
           │
           └─ OpenRouter mode: audio sent as base64 to multimodal LLM

Release ⌥ ─► LLM processes transcription (polish / translate / Q&A)
           │
           ├─ Transcribe/Translate: result copied & auto-pasted
           │
           └─ Q&A: result streamed into dedicated window with Markdown
```

## Project Structure

```
Sources/SwiftTypeless/
├── App/                  # App entry, delegate, state management
├── Core/                 # KeyListener, AudioRecorder, Settings, Output
├── Services/
│   ├── LLM/              # BailianProvider, OpenRouterProvider
│   └── STT/              # AliyunSTTProvider (WebSocket ASR)
└── UI/
    ├── MainWindow/        # HomeView, SettingsView
    ├── OverlayWindow/     # Recording status overlay
    └── QAResultWindow/    # Q&A answer window with Markdown
```

## Dependencies

- [swift-markdown-ui](https://github.com/gonzalezreal/swift-markdown-ui) — Markdown rendering in Q&A answers

All other functionality uses Apple system frameworks (SwiftUI, AVFoundation, AppKit, CoreGraphics).

## License

[CC BY-NC 4.0](https://creativecommons.org/licenses/by-nc/4.0/)

Free for personal and non-commercial use. Commercial use is not permitted without prior written permission.
