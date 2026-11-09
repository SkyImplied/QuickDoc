import SwiftUI

struct LanguageOption: Identifiable {
    let id: String
    let title: String
    let subtitle: String
}

let quickDocLanguageOptions: [LanguageOption] = [
    LanguageOption(id: "zh-Hans", title: "简体中文", subtitle: "适合中国大陆用户"),
    LanguageOption(id: "en", title: "English", subtitle: "International"),
    LanguageOption(id: "ja", title: "日本语", subtitle: "Japanese"),
    LanguageOption(id: "ko", title: "한국어", subtitle: "Korean"),
    LanguageOption(id: "fr", title: "Français", subtitle: "French"),
    LanguageOption(id: "de", title: "Deutsch", subtitle: "German")
]

struct LanguageSettingsCard: View {
    @EnvironmentObject private var model: QuickDocSettingsModel
    @State private var isPresentingLanguageSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsSectionTitle(title: "语言", systemImage: "globe")
            GlassSection {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("软件语言")
                            .font(.body)
                        Text("当前版本只有简体中文。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 12)
                    Button("语言设置") {
                        isPresentingLanguageSheet = true
                    }
                    .glassButtonStyle()
                }
            }
        }
        .sheet(isPresented: $isPresentingLanguageSheet) {
            LanguageSelectionSheet()
                .environmentObject(model)
        }
    }
}
