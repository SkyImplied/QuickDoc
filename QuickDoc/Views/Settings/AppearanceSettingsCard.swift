import SwiftUI

struct AppearanceSettingsCard: View {
    @EnvironmentObject private var model: QuickDocSettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsSectionTitle(title: L("外观"), systemImage: "circle.lefthalf.filled")
            GlassSection {
                HStack(spacing: 8) {
                    ForEach(QuickDocAppearanceMode.allCases) { mode in
                        appearanceButton(for: mode)
                    }
                }
            }
        }
    }

    private func appearanceButton(for mode: QuickDocAppearanceMode) -> some View {
        let isSelected = model.appearanceMode == mode

        return Button {
            model.setAppearanceMode(mode)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: mode.systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                Text(mode.title)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.10) : Color.clear)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected ? Color.accentColor.opacity(0.45) : Color.secondary.opacity(0.14),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(LF("外观模式：%@", mode.title))
        .accessibilityValue(isSelected ? L("已选择") : L("未选择"))
    }
}
