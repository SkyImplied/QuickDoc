import SwiftUI

struct MenuPreviewCard: View {
    @EnvironmentObject private var model: QuickDocSettingsModel
    @State private var isEditingOrder = false
    @State private var editingSelectionOrder: [String] = []
    @State private var baselineVisibleOrder: [String] = []

    var body: some View {
        GlassSection {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("访达右键菜单预览")
                            .font(.headline)
                        Text("这里会模拟 Finder 里“新建文件”的展示顺序，编辑后右键菜单也会同步更新。")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    Button(isEditingOrder ? "完成排序" : "编辑排序") {
                        toggleEditingOrder()
                    }
                    .glassButtonStyle()
                }

                HStack(alignment: .top, spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .center, spacing: 14) {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.accentColor.opacity(0.12))
                                .frame(width: 74, height: 74)
                                .overlay {
                                    Image(systemName: "folder.badge.plus")
                                        .font(.system(size: 30, weight: .semibold))
                                        .foregroundStyle(.blue)
                                }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("右键菜单样式")
                                    .font(.title3.weight(.semibold))
                                Text("当前已启用 \(model.menuPreviewItems.count) 项")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            PreviewTipRow(
                                systemImage: isEditingOrder ? "checklist.checked" : "hand.tap",
                                text: helperText
                            )
                        }

                        Spacer(minLength: 0)
                    }
                    .frame(width: 320, alignment: .leading)

                    menuPreviewPanel
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var helperText: String {
        if isEditingOrder {
            return "请按目标顺序依次点击左侧圆圈。第一次点击排第 1，第二次点击排第 2；再次点击已选项可取消。"
        }

        return "点击“编辑排序”后，可通过左侧圆圈按顺序设置菜单位置，排序后 Finder 右键菜单会同步更新。"
    }

    private var menuPreviewPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles.rectangle.stack")
                    .foregroundStyle(.secondary)
                Text("Finder > 新建文件")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()

            ScrollView {
                if model.menuPreviewItems.isEmpty {
                    PreviewMenuRow(
                        item: MenuPreviewItem(id: "empty", title: "暂无启用的新建类型", templateCount: 0),
                        isEditing: false,
                        selectionRank: nil,
                        showsChevron: false,
                        onSelect: nil
                    )
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
                } else {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(model.menuPreviewItems) { item in
                            PreviewMenuRow(
                                item: item,
                                isEditing: isEditingOrder,
                                selectionRank: selectionRank(for: item.id),
                                showsChevron: !isEditingOrder && item.templateCount > 0,
                                onSelect: isEditingOrder ? {
                                    toggleSelection(for: item.id)
                                } : nil
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .frame(minHeight: 290)
            .animation(.snappy(duration: 0.22), value: model.menuPreviewItems.map(\.id))
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
    }

    private func toggleEditingOrder() {
        if isEditingOrder {
            isEditingOrder = false
            editingSelectionOrder = []
            baselineVisibleOrder = []
            return
        }

        baselineVisibleOrder = model.menuPreviewItems.map(\.id)
        editingSelectionOrder = []
        isEditingOrder = true
    }

    private func toggleSelection(for itemID: String) {
        withAnimation(.snappy(duration: 0.2)) {
            if let index = editingSelectionOrder.firstIndex(of: itemID) {
                editingSelectionOrder.remove(at: index)
            } else {
                editingSelectionOrder.append(itemID)
            }

            model.applyPreviewSelectionOrder(editingSelectionOrder, baseVisibleOrder: baselineVisibleOrder)
        }
    }

    private func selectionRank(for itemID: String) -> Int? {
        guard let index = editingSelectionOrder.firstIndex(of: itemID) else { return nil }
        return index + 1
    }
}

struct PreviewMenuRow: View {
    let item: MenuPreviewItem
    let isEditing: Bool
    let selectionRank: Int?
    let showsChevron: Bool
    let onSelect: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            if isEditing {
                selectionBadge
            }
            previewIcon
                .frame(width: 18, height: 18)
            Text(item.title)
                .lineLimit(1)
            if item.templateCount > 0 {
                Text("\(item.templateCount)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.10), in: Capsule())
            }
            Spacer()
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 38)
        .padding(.horizontal, 14)
        .background(rowBackground)
        .contentShape(Rectangle())
        .onTapGesture {
            guard isEditing else { return }
            onSelect?()
        }
    }

    @ViewBuilder
    private var selectionBadge: some View {
        Button {
            onSelect?()
        } label: {
            ZStack {
                Circle()
                    .stroke(selectionRank == nil ? Color.secondary.opacity(0.45) : Color.accentColor, lineWidth: 1.5)
                    .background(
                        Circle()
                            .fill(selectionRank == nil ? Color.clear : Color.accentColor.opacity(0.14))
                    )
                    .frame(width: 24, height: 24)

                if let selectionRank {
                    Text("\(selectionRank)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .frame(width: 28, height: 28)
            .contentShape(Circle())
        }
        .buttonStyle(.borderless)
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

    @ViewBuilder
    private var rowBackground: some View {
        if isEditing, selectionRank != nil {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.accentColor.opacity(0.08))
        } else {
            Color.clear
        }
    }
}

struct PreviewTipRow: View {
    let systemImage: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.blue)
                .frame(width: 18)

            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
