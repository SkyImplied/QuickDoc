import SwiftUI

struct MenuPreviewCard: View {
    @EnvironmentObject private var model: QuickDocSettingsModel
    @State private var isEditingOrder = false

    var body: some View {
        GlassSection {
            VStack(alignment: .leading, spacing: 20) {
                sectionHeader
                statusBar
                menuPreviewCanvas
            }
        }
    }

    private var sectionHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "cursorarrow.click.2")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 42, height: 42)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("Finder 右键菜单预览")
                    .font(.headline)
                Text("预览“新建文件”子菜单，并调整各文件类型在 Finder 中的显示顺序。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isEditingOrder.toggle()
                }
            } label: {
                Label(isEditingOrder ? "完成排序" : "调整顺序", systemImage: isEditingOrder ? "checkmark" : "arrow.up.arrow.down")
            }
            .glassButtonStyle(prominent: isEditingOrder)
            .disabled(model.menuPreviewItems.count < 2)
        }
    }

    private var statusBar: some View {
        HStack(spacing: 10) {
            MenuPreviewStatusPill(
                systemImage: "doc.on.doc",
                text: "\(model.menuPreviewItems.count) 个文件类型"
            )

            MenuPreviewStatusPill(
                systemImage: "square.stack.3d.up",
                text: "\(visibleTemplateCount) 个自定义模板"
            )

            Spacer(minLength: 12)

            Label(
                isEditingOrder ? "使用每行右侧的箭头调整位置，修改会立即生效" : "带模板的类型会显示为三级菜单",
                systemImage: isEditingOrder ? "info.circle.fill" : "chevron.right.2"
            )
            .font(.caption)
            .foregroundStyle(isEditingOrder ? Color.accentColor : Color.secondary)
            .lineLimit(1)
        }
    }

    private var menuPreviewCanvas: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.055),
                    Color.primary.opacity(0.018),
                    Color.accentColor.opacity(0.035)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 14) {
                HStack(spacing: 7) {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(Color.accentColor)
                    Text("Finder")
                        .fontWeight(.semibold)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(isEditingOrder ? "正在调整菜单顺序" : "空白处右键  ›  新建文件")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)

                finderMenu
                    .frame(maxWidth: 540)
            }
            .padding(.horizontal, 42)
            .padding(.vertical, 24)
        }
        .frame(maxWidth: .infinity, minHeight: 390)
        .background(Color.primary.opacity(0.02))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var finderMenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text("新建文件")
                        .font(.callout.weight(.semibold))
                    Text(isEditingOrder ? "按你的使用习惯排列" : "QuickDoc Finder 扩展")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isEditingOrder {
                    Text("排序模式")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.10), in: Capsule())
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            Divider()

            ScrollView {
                if model.menuPreviewItems.isEmpty {
                    emptyMenuView
                } else {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(model.menuPreviewItems.enumerated()), id: \.element.id) { index, item in
                            PreviewMenuRow(
                                item: item,
                                position: index,
                                totalCount: model.menuPreviewItems.count,
                                isEditing: isEditingOrder,
                                onMoveUp: { moveItem(at: index, offset: -1) },
                                onMoveDown: { moveItem(at: index, offset: 1) }
                            )
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 7)
                }
            }
            .frame(minHeight: 280, maxHeight: 430)
            .animation(.easeInOut(duration: 0.18), value: model.menuPreviewItems.map(\.id))

            if !model.menuPreviewItems.isEmpty {
                Divider()

                HStack(spacing: 7) {
                    Image(systemName: isEditingOrder ? "arrow.up.arrow.down.circle" : "eye")
                    Text(isEditingOrder ? "顺序会自动保存并同步到 Finder" : "以上是当前 Finder 菜单中的实际显示顺序")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.10), radius: 18, y: 8)
    }

    private var emptyMenuView: some View {
        VStack(spacing: 9) {
            Image(systemName: "doc.badge.ellipsis")
                .font(.system(size: 25))
                .foregroundStyle(.secondary)
            Text("暂无启用的文件类型")
                .font(.callout.weight(.semibold))
            Text("请在上方选择要显示在 Finder 中的类型。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 245)
    }

    private var visibleTemplateCount: Int {
        model.menuPreviewItems.reduce(0) { $0 + $1.templateCount }
    }

    private func moveItem(at index: Int, offset: Int) {
        let targetIndex = index + offset
        guard model.menuPreviewItems.indices.contains(index),
              model.menuPreviewItems.indices.contains(targetIndex) else {
            return
        }

        var order = model.menuPreviewItems.map(\.id)
        order.swapAt(index, targetIndex)
        model.applyPreviewSelectionOrder(order, baseVisibleOrder: order)
    }
}

struct PreviewMenuRow: View {
    let item: MenuPreviewItem
    let position: Int
    let totalCount: Int
    let isEditing: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            if isEditing {
                Text("\(position + 1)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 24, height: 24)
                    .background(Color.accentColor.opacity(0.10), in: Circle())
            }

            previewIcon
                .frame(width: 18, height: 18)

            Text(item.title)
                .font(.callout)
                .lineLimit(1)

            if item.templateCount > 0 {
                Text("\(item.templateCount) 个模板")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.09), in: Capsule())
            }

            Spacer(minLength: 8)

            if isEditing {
                HStack(spacing: 2) {
                    Button(action: onMoveUp) {
                        Image(systemName: "chevron.up")
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .disabled(position == 0)
                    .help("上移")

                    Button(action: onMoveDown) {
                        Image(systemName: "chevron.down")
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .disabled(position == totalCount - 1)
                    .help("下移")
                }
                .buttonStyle(.borderless)
            } else if item.templateCount > 0 {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: isEditing ? 42 : 36)
        .padding(.horizontal, 10)
        .background(
            isEditing ? Color.accentColor.opacity(0.045) : Color.clear,
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
    }

    @ViewBuilder
    private var previewIcon: some View {
        if let image = QuickDocIcon.icon(for: item.id, size: NSSize(width: 18, height: 18)) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "doc")
                .foregroundStyle(.secondary)
        }
    }
}

struct MenuPreviewStatusPill: View {
    let systemImage: String
    let text: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.055), in: Capsule())
    }
}
