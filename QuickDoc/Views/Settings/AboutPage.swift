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

            AboutFeatureGrid()

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

private struct AboutFeatureGrid: View {
    @State private var titleHeight: CGFloat = 0

    var body: some View {
        EqualFeatureGrid {
            feature("doc.badge.plus", "多类型文件一键新建", "支持常用文档、代码与空白文件。")
            feature("rectangle.and.hand.point.up.left", "Finder 右键与工具栏", "在 Finder 右键菜单或工具栏快速新建文件。")
            feature("menubar.rectangle", "菜单栏快捷配置", "在菜单栏调整显示方式与常用功能。")
            feature("terminal", "自定义终端与路径操作", "用指定终端打开当前文件夹，或复制路径。")
            feature("slider.horizontal.3", "菜单内容可自定义", "管理文件类型、自定义后缀及显示顺序。")
            feature("checkmark.shield", "扩展状态与更新管理", "查看扩展状态、打开系统设置并检查更新。")
        }
        .onPreferenceChange(AboutTitleHeightPreference.self) { newValue in
            guard newValue > 0, abs(titleHeight - newValue) > 0.5 else { return }
            titleHeight = newValue
        }
    }

    private func feature(_ systemImage: String, _ title: String, _ subtitle: String) -> some View {
        AboutFeatureCard(systemImage: systemImage, title: title, subtitle: subtitle, titleHeight: titleHeight)
    }
}

private struct EqualFeatureGrid: Layout {
    var minimumColumnWidth: CGFloat = 220
    var spacing: CGFloat = 14

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        let metrics = metrics(for: width)
        let cardHeight = tallestCard(subviews, width: metrics.cardWidth)
        let rows = Int(ceil(Double(subviews.count) / Double(metrics.columns)))
        let height = CGFloat(rows) * cardHeight + CGFloat(max(0, rows - 1)) * spacing
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let metrics = metrics(for: bounds.width)
        let cardHeight = tallestCard(subviews, width: metrics.cardWidth)
        for (index, subview) in subviews.enumerated() {
            let row = index / metrics.columns
            let column = index % metrics.columns
            let origin = CGPoint(
                x: bounds.minX + metrics.inset + CGFloat(column) * (metrics.cardWidth + spacing),
                y: bounds.minY + CGFloat(row) * (cardHeight + spacing)
            )
            subview.place(
                at: origin,
                anchor: .topLeading,
                proposal: ProposedViewSize(width: metrics.cardWidth, height: cardHeight)
            )
        }
    }

    private func columnCount(for width: CGFloat) -> Int {
        guard width > 0 else { return 1 }
        let count = Int((width + spacing) / (minimumColumnWidth + spacing))
        return max(1, min(count, 6))
    }

    private func metrics(for width: CGFloat) -> (columns: Int, cardWidth: CGFloat, inset: CGFloat) {
        let columns = columnCount(for: width)
        let raw = (width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
        let cardWidth = floor(raw)
        let used = cardWidth * CGFloat(columns) + spacing * CGFloat(max(0, columns - 1))
        let inset = max(0, (width - used) / 2)
        return (columns, cardWidth, inset)
    }

    private func tallestCard(_ subviews: Subviews, width: CGFloat) -> CGFloat {
        subviews.map { subview in
            subview.sizeThatFits(ProposedViewSize(width: width, height: nil)).height
        }.max() ?? 0
    }
}

private struct AboutTitleHeightPreference: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct AboutFeatureCard: View {
    let systemImage: String
    let title: String
    let subtitle: String
    var titleHeight: CGFloat = 0

    var body: some View {
        GlassSection(fillsAvailableHeight: true) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 36, height: 36)
                    .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text(title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                    .overlay {
                        GeometryReader { proxy in
                            Color.clear.preference(key: AboutTitleHeightPreference.self, value: proxy.size.height)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: titleHeight, alignment: .topLeading)

                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .accessibilityIdentifier("about-feature")
        .background(AboutCardFrameMarker())
    }
}

private struct AboutCardFrameMarker: NSViewRepresentable {
    func makeNSView(context: Context) -> AboutCardFrameView { AboutCardFrameView() }
    func updateNSView(_ nsView: AboutCardFrameView, context: Context) {}
}

final class AboutCardFrameView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
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
