import SwiftUI

struct GeneralSettingsPage: View {
    @EnvironmentObject private var model: QuickDocSettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(title: L("通用设置"))

            StartupSettingsCard()

            DisplayModeSettingsCard()
            AppearanceSettingsCard()
            SoftwareUpdateSettingsCard()
            LanguageSettingsCard()
        }
    }
}

private struct StartupSettingsCard: View {
    @EnvironmentObject private var model: QuickDocSettingsModel

    var body: some View {
        SettingsGroup(title: L("启动"), systemImage: "power") {
            startupToggle(title: L("开机自启动"), isOn: $model.launchAtLogin)

            Divider()

            startupToggle(
                title: L("静默启动"),
                isOn: $model.silentLaunchAtLogin,
                isEnabled: model.launchAtLogin,
                dependencyText: L("需先开启开机自启动")
            )
        }
    }

    private func startupToggle(
        title: String,
        isOn: Binding<Bool>,
        isEnabled: Bool = true,
        dependencyText: String? = nil
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.body)
            if !isEnabled, let dependencyText {
                Text(dependencyText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(!isEnabled)
                .accessibilityLabel(title)
        }
        .padding(.vertical, 4)
        .opacity(isEnabled ? 1 : 0.64)
    }
}

struct DisplayModeSettingsCard: View {
    @EnvironmentObject private var model: QuickDocSettingsModel

    var body: some View {
        SettingsGroup(title: L("显示方式"), systemImage: "macwindow") {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(QuickDocDisplayMode.allCases) { mode in
                    DisplayModeOptionCard(
                        mode: mode,
                        isSelected: model.displayMode == mode
                    ) {
                        model.requestDisplayModeChange(mode)
                    }
                }
            }
        }
    }
}

private struct DisplayModeOptionCard: View {
    let mode: QuickDocDisplayMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 10) {
                DisplayModeMiniature(mode: mode, isSelected: isSelected)
                Text(mode.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 4)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.42))
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .background(
                isSelected ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.03),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.45) : Color.primary.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(LF("显示方式：%@", mode.title))
        .accessibilityValue(isSelected ? L("已选择") : L("未选择"))
    }
}

private struct DisplayModeMiniature: View {
    let mode: QuickDocDisplayMode
    let isSelected: Bool

    private var activeColor: Color {
        isSelected ? .accentColor : .secondary
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.10) : Color.primary.opacity(0.045))

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(Color.secondary.opacity(0.32), lineWidth: 1)
                .frame(width: 32, height: 22)

            if mode.showsStatusItem {
                HStack(spacing: 2) {
                    Spacer()
                    Circle().fill(activeColor).frame(width: 3, height: 3)
                    Circle().fill(activeColor.opacity(0.55)).frame(width: 3, height: 3)
                }
                .padding(.horizontal, 3)
                .frame(width: 32, height: 6)
                .background(activeColor.opacity(0.16))
                .offset(y: -8)
            }

            if mode.activationPolicy == .regular {
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1, style: .continuous)
                            .fill(activeColor)
                            .frame(width: 4, height: 4)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(activeColor.opacity(0.15), in: Capsule())
                .offset(y: 12)
            }

            if mode == .hiddenBoth {
                Image(systemName: "eye.slash.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 44, height: 44)
        .accessibilityHidden(true)
    }
}

private struct SettingsGroup<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsSectionTitle(title: title, systemImage: systemImage)
            GlassSection {
                VStack(alignment: .leading, spacing: 8) {
                    content
                }
            }
        }
    }
}

struct SettingsSectionTitle: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 22, height: 22)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

