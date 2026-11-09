import SwiftUI

struct MenuPreviewCard: View {
    @EnvironmentObject private var model: QuickDocSettingsModel
    @State private var isEditingOrder = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                SettingsSectionTitle(title: "菜单顺序", systemImage: "list.bullet")
                Spacer(minLength: 8)
                Button(isEditingOrder ? "完成" : "调整顺序") {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isEditingOrder.toggle()
                    }
                }
                .disabled(model.menuPreviewItems.count < 2)
            }

            GlassSection {
                VStack(alignment: .leading, spacing: 8) {
                    Text(isEditingOrder ? "用右侧箭头调整，松开后立即生效。" : "当前「新建文件」菜单。带模板的项目会展开子菜单。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    finderMenu
                }
            }
        }
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

            Group {
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
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                }
            }
            .animation(.easeInOut(duration: 0.18), value: model.menuPreviewItems.map(\.id))

            if !model.menuPreviewItems.isEmpty, isEditingOrder {
                Text("顺序会保存并同步到 Finder。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 6)
            }
        }
    }

    private var emptyMenuView: some View {
        Text("还没有启用的文件类型。")
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
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
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
            }

            previewIcon
                .frame(width: 18, height: 18)

            Text(item.title)
                .font(.callout)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if item.templateCount > 0 {
                Text("\(item.templateCount) 个模板")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
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
            isEditing ? Color.primary.opacity(0.04) : Color.clear,
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

