import SwiftUI
import Cocoa
import UniformTypeIdentifiers

struct CustomTemplatesCard: View {
    @EnvironmentObject private var model: QuickDocSettingsModel
    @State private var selectedFileTypeID: String?
    @State private var selectedTemplateURL: URL?
    @State private var templateDisplayName = ""
    @State private var shouldShowInContextMenu = true

    var body: some View {
        GlassSection {
            VStack(alignment: .leading, spacing: 20) {
                sectionHeader

                if model.templateFileTypes.isEmpty {
                    emptyFileTypesView
                } else {
                    HStack(alignment: .top, spacing: 0) {
                        templateTypeList
                            .frame(width: 232)

                        Divider()

                        if let selectedType {
                            templateTypeDetail(for: selectedType)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                    }
                    .background(
                        Color.primary.opacity(0.025),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
        .onAppear(perform: ensureSelectedFileType)
        .onChange(of: model.templateFileTypes) { _ in
            ensureSelectedFileType()
        }
        .onChange(of: selectedFileTypeID) { _ in
            resetComposer()
        }
    }

    private var sectionHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "doc.on.doc.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 42, height: 42)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("自定义文件模板")
                    .font(.headline)
                Text("选择一种文件类型，添加常用模板并设置它们在 Finder 右键菜单中的顺序。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            Label("\(model.customTemplates.count) 个", systemImage: "square.stack.3d.up")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.06), in: Capsule())
        }
    }

    private var emptyFileTypesView: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("还没有可管理的文件类型")
                .font(.callout.weight(.semibold))
            Text("请先在上方启用内置类型，或添加一种自定义后缀。")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var selectedType: TemplateFileType? {
        if let selectedFileTypeID,
           let type = model.templateFileTypes.first(where: { $0.id == selectedFileTypeID }) {
            return type
        }

        return model.templateFileTypes.first
    }

    private var templateTypeList: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("文件类型")
                    .font(.callout.weight(.semibold))
                Text("选择要管理的类型")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(model.templateFileTypes) { type in
                        templateTypeRow(for: type)
                    }
                }
            }
        }
        .padding(14)
        .frame(minHeight: 470, maxHeight: 620, alignment: .top)
    }

    private func templateTypeRow(for type: TemplateFileType) -> some View {
        let templates = model.customTemplates(for: type.id)
        let visibleCount = templates.filter(\.isVisibleInContextMenu).count

        return Button {
            selectedFileTypeID = type.id
        } label: {
            HStack(spacing: 10) {
                templateIcon(for: type)
                    .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(type.title)
                        .font(.callout.weight(isSelected(type) ? .semibold : .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(templates.isEmpty ? "尚无模板" : "\(visibleCount) 个显示")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                if !templates.isEmpty {
                    Text("\(templates.count)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(isSelected(type) ? Color.accentColor : Color.secondary)
                        .frame(minWidth: 22, minHeight: 20)
                        .background(Color.primary.opacity(0.06), in: Capsule())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected(type) ? Color.accentColor.opacity(0.13) : Color.clear,
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .overlay(alignment: .leading) {
                if isSelected(type) {
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: 3, height: 22)
                        .padding(.leading, 2)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func templateTypeDetail(for type: TemplateFileType) -> some View {
        let templates = model.customTemplates(for: type.id)
        let visibleCount = templates.filter(\.isVisibleInContextMenu).count

        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                templateIcon(for: type)
                    .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(type.title)
                            .font(.title3.weight(.semibold))
                        Text(".\(type.pathExtension.lowercased())")
                            .font(.caption.monospaced().weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.primary.opacity(0.06), in: Capsule())
                    }

                    Label("新建文件  ›  \(menuTitle(for: type))", systemImage: "menucard")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                Button {
                    chooseTemplateFile(for: type)
                } label: {
                    Label("添加模板", systemImage: "plus")
                }
                .glassButtonStyle(prominent: templates.isEmpty)
            }

            if selectedTemplateURL != nil {
                templateComposer(for: type)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Divider()

            HStack {
                Text("已添加模板")
                    .font(.callout.weight(.semibold))

                Spacer()

                if !templates.isEmpty {
                    Text("\(visibleCount) / \(templates.count) 个显示在右键菜单")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if templates.isEmpty {
                emptyTemplatesView(for: type)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(templates.enumerated()), id: \.element.id) { index, template in
                        CustomTemplateRow(
                            rank: index + 1,
                            template: template,
                            fileExists: model.customTemplateFileExists(template),
                            canMoveUp: model.canMoveCustomTemplate(template.id, direction: .up),
                            canMoveDown: model.canMoveCustomTemplate(template.id, direction: .down)
                        )
                    }
                }
            }
        }
        .padding(18)
        .animation(.easeInOut(duration: 0.18), value: selectedTemplateURL)
    }

    private func emptyTemplatesView(for type: TemplateFileType) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 26))
                .foregroundStyle(.secondary)
            Text("还没有 .\(type.pathExtension) 模板")
                .font(.callout.weight(.semibold))
            Text("添加后可直接从 Finder 右键菜单创建带有预设内容的新文件。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 230)
    }

    private func templateComposer(for type: TemplateFileType) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 34, height: 34)
                    .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("添加新模板")
                        .font(.callout.weight(.semibold))
                    Text(selectedTemplateURL?.lastPathComponent ?? "未选择文件")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Button("更换文件") {
                    chooseTemplateFile(for: type)
                }
                .buttonStyle(.borderless)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("右键菜单显示名称")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                TextField("例如：合同模板", text: $templateDisplayName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        if canAddTemplate(for: type) {
                            addTemplate(for: type)
                        }
                    }
            }

            HStack(spacing: 12) {
                Toggle("添加后显示在 Finder 右键菜单", isOn: $shouldShowInContextMenu)
                    .toggleStyle(.checkbox)

                Spacer(minLength: 8)

                Button("取消") {
                    resetComposer()
                }
                .buttonStyle(.borderless)

                Button {
                    addTemplate(for: type)
                } label: {
                    Text("添加模板")
                }
                .glassButtonStyle(prominent: true)
                .disabled(!canAddTemplate(for: type))
            }

            Text(addTemplateHint(for: type))
                .font(.caption)
                .foregroundStyle(canAddTemplate(for: type) ? Color.secondary : Color.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Color.accentColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.accentColor.opacity(0.18), lineWidth: 1)
        }
    }

    private func canAddTemplate(for type: TemplateFileType) -> Bool {
        selectedTemplateURL != nil
            && !templateDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && model.templateFileTypeID(matchingPathExtension: selectedTemplateURL?.pathExtension ?? "") == type.id
    }

    private func addTemplateHint(for type: TemplateFileType) -> String {
        guard let selectedTemplateURL else {
            return "请选择一个 .\(type.pathExtension) 文件。"
        }

        let selectedExtension = selectedTemplateURL.pathExtension.lowercased()
        guard selectedExtension == type.pathExtension else {
            return "当前文件是 .\(selectedExtension.isEmpty ? "无后缀" : selectedExtension)，请改选 .\(type.pathExtension) 文件。"
        }

        guard !templateDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "请输入模板在右键菜单中的显示名称。"
        }

        return "文件会复制到 QuickDoc 的模板目录，原文件保持不变。"
    }

    private func ensureSelectedFileType() {
        if let selectedFileTypeID,
           model.templateFileTypes.contains(where: { $0.id == selectedFileTypeID }) {
            return
        }

        selectedFileTypeID = model.templateFileTypes.first(where: { $0.id == "docx" })?.id
            ?? model.templateFileTypes.first?.id
    }

    private func chooseTemplateFile(for type: TemplateFileType) {
        let panel = NSOpenPanel()
        panel.title = "选择模板文件"
        panel.message = "请选择一个 .\(type.pathExtension) 文件作为 \(type.title) 模板。"
        panel.prompt = "选择"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if let contentType = UTType(filenameExtension: type.pathExtension) {
            panel.allowedContentTypes = [contentType]
        }

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        selectedTemplateURL = url
        templateDisplayName = url.deletingPathExtension().lastPathComponent
    }

    private func addTemplate(for type: TemplateFileType) {
        guard let selectedTemplateURL else { return }

        guard model.addCustomTemplate(
            from: selectedTemplateURL,
            displayName: templateDisplayName,
            fileTypeID: type.id,
            isVisibleInContextMenu: shouldShowInContextMenu
        ) else {
            return
        }

        resetComposer()
    }

    private func resetComposer() {
        selectedTemplateURL = nil
        templateDisplayName = ""
        shouldShowInContextMenu = true
    }

    private func isSelected(_ type: TemplateFileType) -> Bool {
        selectedType?.id == type.id
    }

    private func menuTitle(for type: TemplateFileType) -> String {
        model.menuTitle(forTemplateFileTypeID: type.id) ?? "新建 \(type.pathExtension.uppercased()) 文件"
    }

    @ViewBuilder
    private func templateIcon(for type: TemplateFileType) -> some View {
        if let image = QuickDocIcon.icon(for: type.id, size: NSSize(width: 22, height: 22)) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "doc")
                .foregroundStyle(.secondary)
        }
    }
}

struct CustomTemplateRow: View {
    @EnvironmentObject private var model: QuickDocSettingsModel
    let rank: Int
    let template: CustomTemplate
    let fileExists: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool

    var body: some View {
        HStack(spacing: 11) {
            Text("\(rank)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)
                .frame(width: 18)

            Toggle("", isOn: Binding(
                get: { template.isVisibleInContextMenu },
                set: { model.setCustomTemplate(template.id, visibleInContextMenu: $0) }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()
            .help(template.isVisibleInContextMenu ? "在右键菜单中显示" : "已从右键菜单隐藏")

            Image(systemName: fileExists ? "doc.fill" : "doc.badge.ellipsis")
                .font(.system(size: 15))
                .foregroundStyle(fileExists ? Color.accentColor : Color.red)
                .frame(width: 30, height: 30)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(template.displayName)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)

                    if !fileExists {
                        statusBadge("文件缺失", color: .red)
                    } else if !template.isVisibleInContextMenu {
                        statusBadge("已隐藏", color: .secondary)
                    }
                }

                Text(template.originalFileName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Menu {
                Button {
                    model.moveCustomTemplate(template.id, direction: .up)
                } label: {
                    Label("上移", systemImage: "arrow.up")
                }
                .disabled(!canMoveUp)

                Button {
                    model.moveCustomTemplate(template.id, direction: .down)
                } label: {
                    Label("下移", systemImage: "arrow.down")
                }
                .disabled(!canMoveDown)

                Divider()

                Button {
                    model.renameCustomTemplate(template.id)
                } label: {
                    Label("重命名", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    model.removeCustomTemplate(template.id)
                } label: {
                    Label("删除模板", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("更多操作")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .contextMenu {
            Button("重命名") {
                model.renameCustomTemplate(template.id)
            }
            Button("上移") {
                model.moveCustomTemplate(template.id, direction: .up)
            }
            .disabled(!canMoveUp)
            Button("下移") {
                model.moveCustomTemplate(template.id, direction: .down)
            }
            .disabled(!canMoveDown)
            Divider()
            Button("删除模板", role: .destructive) {
                model.removeCustomTemplate(template.id)
            }
        }
    }

    private func statusBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.10), in: Capsule())
    }
}
