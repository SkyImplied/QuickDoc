import SwiftUI

struct AboutPage: View {
    @EnvironmentObject private var model: QuickDocSettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageHeader(title: "关于", subtitle: "从 Finder 右键菜单、工具栏和菜单栏快速创建文件，并管理常用 Finder 操作。")

            GlassSection {
                HStack(spacing: 18) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 72, height: 72)
                        .shadow(radius: 8, y: 4)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("QuickDoc")
                            .font(.title2.weight(.bold))
                        Text("版本 v\(model.appVersion)")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("围绕 Finder Sync 扩展构建的 macOS 效率工具，让新建文件、打开终端、复制路径和扩展管理都更顺手。")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()
                }
            }

            LazyVGrid(columns: [
                GridItem(.flexible(minimum: 220), spacing: 14),
                GridItem(.flexible(minimum: 220), spacing: 14)
            ], alignment: .leading, spacing: 14) {
                AboutFeatureCard(
                    systemImage: "doc.badge.plus",
                    title: "多类型文件一键新建",
                    subtitle: "内置 TXT、Markdown、Word、Excel、CSV、PowerPoint、JSON、Python、HTML、Shell、RTF 和空白文件。"
                )
                AboutFeatureCard(
                    systemImage: "rectangle.and.hand.point.up.left",
                    title: "Finder 右键与工具栏",
                    subtitle: "可在文件夹空白处、选中文件夹或桌面右键创建文件，也支持添加到 Finder 工具栏直接调用。"
                )
                AboutFeatureCard(
                    systemImage: "menubar.rectangle",
                    title: "菜单栏快捷配置",
                    subtitle: "常驻菜单栏后，可直接调整新建文件类型和其他 Finder 快捷功能，不必每次打开主窗口。"
                )
                AboutFeatureCard(
                    systemImage: "terminal",
                    title: "自定义终端与路径操作",
                    subtitle: "支持用你选择的终端 App 打开当前 Finder 文件夹，也可在右键菜单中复制当前路径。"
                )
                AboutFeatureCard(
                    systemImage: "slider.horizontal.3",
                    title: "菜单内容可自定义",
                    subtitle: "可启用或隐藏内置文件类型、添加自定义后缀，并通过菜单预览调整显示顺序。"
                )
                AboutFeatureCard(
                    systemImage: "checkmark.shield",
                    title: "扩展状态与更新管理",
                    subtitle: "在应用内检查 Finder Sync 启用状态、一键前往系统设置，并支持确认后自动下载安装更新。"
                )
            }

            GlassSection {
                VStack(alignment: .leading, spacing: 10) {
                    Label("声明", systemImage: "info.circle")
                        .font(.headline)
                    Text("本软件为免费开源项目，仅供交流学习与个人使用。请遵守相关法律法规与开源协议，勿用于任何商业或非法用途。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            GlassSection {
                VStack(alignment: .leading, spacing: 12) {
                    Label("联系与主页", systemImage: "link")
                        .font(.headline)

                    ContactRow(title: "Bilibili", value: "默示天空")
                    ContactRow(title: "GitHub", value: "SkyImplied")
                    ContactRow(title: "邮箱", value: "skyimplied@163.com")
                    ContactRow(title: "交流QQ群", value: "201478754")
                }
            }
        }
    }
}

struct AboutFeatureCard: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        GlassSection {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 36, height: 36)
                    .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct ContactRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.callout)
        }
    }
}
