import MarkdownUI
import SwiftUI

/// Thin wrapper around MarkdownUI's Markdown view, styled for the QA window.
struct MarkdownView: View {
    let text: String

    var body: some View {
        Markdown(text)
            .markdownTheme(qaTheme)
    }

    private var qaTheme: MarkdownUI.Theme {
        Theme()
            .text {
                ForegroundColor(Color.textPrimary)
                FontSize(14)
            }
            .code {
                FontFamilyVariant(.monospaced)
                FontSize(12.5)
                ForegroundColor(Color.accent)
            }
            .codeBlock { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontFamilyVariant(.monospaced)
                        FontSize(12.5)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.surfaceLight, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderStrong, lineWidth: 1))
            }
    }
}
