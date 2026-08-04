import SwiftUI

struct AppearanceSettingsCard: View {
    @EnvironmentObject private var model: QuickDocSettingsModel

    var body: some View {
        GlassSection {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: "circle.lefthalf.filled")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 40, height: 40)
                        .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("外观模式")
                            .font(.headline)
                        Text("选择 QuickDoc 的界面外观；跟随系统时会随 macOS 自动切换。")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 12) {
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
            VStack(spacing: 8) {
                Image(systemName: mode.systemImage)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)

                Text(mode.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(mode.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 104)
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
        .accessibilityLabel("外观模式：\(mode.title)")
        .accessibilityValue(isSelected ? "已选择" : "未选择")
    }
}
