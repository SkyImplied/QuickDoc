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
        GlassSection {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "globe")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 40, height: 40)
                    .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("软件语言")
                        .font(.headline)
                    Text("点击后再选择语言，当前版本暂不支持实际切换。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button("语言设置") {
                    isPresentingLanguageSheet = true
                }
                .glassButtonStyle()
            }
        }
        .sheet(isPresented: $isPresentingLanguageSheet) {
            LanguageSelectionSheet()
                .environmentObject(model)
        }
    }
}
