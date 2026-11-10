import SwiftUI

struct QuickDocLanguageChoice: Identifiable {
    let id: String
    let endonym: String
}

let quickDocLanguageChoices: [QuickDocLanguageChoice] = [
    QuickDocLanguageChoice(id: "system", endonym: ""),
    QuickDocLanguageChoice(id: "zh-Hans", endonym: "简体中文"),
    QuickDocLanguageChoice(id: "zh-Hant", endonym: "繁體中文"),
    QuickDocLanguageChoice(id: "en", endonym: "English"),
    QuickDocLanguageChoice(id: "ja", endonym: "日本語")
]

struct LanguageSettingsCard: View {
    @State private var isPresentingLanguageSheet = false
    @State private var languageRevision = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsSectionTitle(title: L("语言"), systemImage: "globe")
            GlassSection {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("软件语言"))
                            .font(.body)
                        Text(currentLanguageName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 12)
                    Button(L("语言设置")) {
                        isPresentingLanguageSheet = true
                    }
                    .glassButtonStyle()
                }
            }
        }
        .onAppear {
            #if SIDEBAR_PREVIEW
            if QuickDocPreviewSelection.presentLanguageSheet {
                isPresentingLanguageSheet = true
            }
            #endif
        }
        .onReceive(NotificationCenter.default.publisher(for: .quickDocLanguageDidChange)) { _ in
            languageRevision += 1
        }
        .id(languageRevision)
        .sheet(isPresented: $isPresentingLanguageSheet) {
            LanguageSelectionSheet()
                .compactLanguageSheet()
        }
    }

    private var currentLanguageName: String {
        guard let choice = quickDocLanguageChoices.first(where: { $0.id == currentChoiceID }) else {
            return L("跟随系统")
        }
        return choice.endonym.isEmpty ? L("跟随系统") : choice.endonym
    }

    private var currentChoiceID: String {
        if let override = QuickDocLocalization.previewOverride {
            return override
        }
        return QuickDocLocalization.explicitChoice() ?? "system"
    }
}

struct LanguageSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var languageRevision = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("选择软件语言"))
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(Array(quickDocLanguageChoices.enumerated()), id: \.element.id) { index, choice in
                    if index > 0 {
                        Divider()
                            .padding(.leading, 12)
                    }
                    languageRow(choice)
                }
            }
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            HStack {
                Spacer()
                Button(L("关闭")) {
                    dismiss()
                }
                .controlSize(.small)
                .keyboardShortcut(.cancelAction)
                .glassButtonStyle()
            }
        }
        .padding(14)
        .frame(width: 248)
        .onReceive(NotificationCenter.default.publisher(for: .quickDocLanguageDidChange)) { _ in
            languageRevision += 1
        }
        .id(languageRevision)
    }

    private func languageRow(_ choice: QuickDocLanguageChoice) -> some View {
        let title = choice.endonym.isEmpty ? L("跟随系统") : choice.endonym
        let selected = currentChoiceID == choice.id
        return Button {
            QuickDocLocalization.select(choice.id == "system" ? nil : choice.id)
        } label: {
            HStack(spacing: 8) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(selected ? L("已选择") : L("未选择"))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var currentChoiceID: String {
        if let override = QuickDocLocalization.previewOverride {
            return override
        }
        return QuickDocLocalization.explicitChoice() ?? "system"
    }
}

private extension View {
    @ViewBuilder
    func compactLanguageSheet() -> some View {
        if #available(macOS 15.0, *) {
            self.presentationSizing(.fitted)
        } else {
            self
        }
    }
}
