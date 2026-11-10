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
        VStack(alignment: .leading, spacing: 8) {
            SettingsSectionTitle(title: L("文件模板"), systemImage: "doc.on.doc")
            GlassSection {
                if model.templateFileTypes.isEmpty {
                    emptyFileTypesView
                } else {
                    HStack(alignment: .top, spacing: 0) {
                        templateTypeList
                            .frame(width: 196)

                        Divider()

                        if let selectedType {
                            templateTypeDetail(for: selectedType)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                    }
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

    private var emptyFileTypesView: some View {
        Text(L("先启用带后缀的类型，或添加自定义后缀。"))
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
    }

    private var selectedType: TemplateFileType? {
        if let selectedFileTypeID,
           let type = model.templateFileTypes.first(where: { $0.id == selectedFileTypeID }) {
            return type
        }

        return model.templateFileTypes.first
    }

    private var templateTypeList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("类型"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(model.templateFileTypes) { type in
                        templateTypeRow(for: type)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.trailing, 8)
        .frame(minHeight: 220, maxHeight: 320, alignment: .top)
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
                    HStack(spacing: 4) {
                        Text(shortTitle(for: type))
                            .font(.callout.weight(isSelected(type) ? .semibold : .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(".\(type.pathExtension.lowercased())")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Text(templates.isEmpty ? L("尚无模板") : LF("%ld 个显示", visibleCount))
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
                isSelected(type) ? Color.primary.opacity(0.06) : Color.clear,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
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

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                templateIcon(for: type)
                    .frame(width: 20, height: 20)

                Text(shortTitle(for: type))
                    .font(.body.weight(.semibold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(".\(type.pathExtension.lowercased())")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Button(L("添加模板")) {
                    chooseTemplateFile(for: type)
                }
            }

            if selectedTemplateURL != nil {
                templateComposer(for: type)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Divider()

            if !templates.isEmpty {
                Text(LF("%ld/%ld 显示在右键菜单", visibleCount, templates.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        .padding(.leading, 14)
        .padding(.vertical, 4)
        .animation(.easeInOut(duration: 0.18), value: selectedTemplateURL)
    }

    private func emptyTemplatesView(for type: TemplateFileType) -> some View {
        Text(LF("还没有 .%@ 模板。添加后可创建带预设内容的文件。", type.pathExtension))
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
    }

    private func templateComposer(for type: TemplateFileType) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("新模板"))
                        .font(.callout.weight(.semibold))
                    Text(selectedTemplateURL?.lastPathComponent ?? L("未选择文件"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Button(L("更换文件")) {
                    chooseTemplateFile(for: type)
                }
                .buttonStyle(.borderless)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(L("右键菜单显示名称"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                TextField(L("例如：合同模板"), text: $templateDisplayName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        if canAddTemplate(for: type) {
                            addTemplate(for: type)
                        }
                    }
            }

            HStack(spacing: 12) {
                Toggle(L("添加后显示在 Finder 右键菜单"), isOn: $shouldShowInContextMenu)
                    .toggleStyle(.checkbox)

                Spacer(minLength: 8)

                Button(L("取消")) {
                    resetComposer()
                }
                .buttonStyle(.borderless)

                Button {
                    addTemplate(for: type)
                } label: {
                    Text(L("添加模板"))
                }
                .glassButtonStyle(prominent: true)
                .disabled(!canAddTemplate(for: type))
            }

            Text(addTemplateHint(for: type))
                .font(.caption)
                .foregroundStyle(canAddTemplate(for: type) ? Color.secondary : Color.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func canAddTemplate(for type: TemplateFileType) -> Bool {
        selectedTemplateURL != nil
            && !templateDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && model.templateFileTypeID(matchingPathExtension: selectedTemplateURL?.pathExtension ?? "") == type.id
    }

    private func addTemplateHint(for type: TemplateFileType) -> String {
        guard let selectedTemplateURL else {
            return LF("请选择一个 .%@ 文件。", type.pathExtension)
        }

        let selectedExtension = selectedTemplateURL.pathExtension.lowercased()
        guard selectedExtension == type.pathExtension else {
            return LF("当前文件是 .%@，请改选 .%@ 文件。", selectedExtension.isEmpty ? L("无后缀") : selectedExtension, type.pathExtension)
        }

        guard !templateDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return L("请输入模板在右键菜单中的显示名称。")
        }

        return L("文件会复制到 QuickDoc 的模板目录，原文件保持不变。")
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
        panel.title = L("选择模板文件")
        panel.message = LF("请选择一个 .%@ 文件作为 %@ 模板。", type.pathExtension, type.title)
        panel.prompt = L("选择")
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

    private func shortTitle(for type: TemplateFileType) -> String {
        let suffix = " (.\(type.pathExtension))"
        guard type.title.hasSuffix(suffix) else { return type.title }
        return String(type.title.dropLast(suffix.count))
    }

    private func isSelected(_ type: TemplateFileType) -> Bool {
        selectedType?.id == type.id
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
            .help(template.isVisibleInContextMenu ? L("在右键菜单中显示") : L("已从右键菜单隐藏"))

            Image(systemName: fileExists ? "doc.fill" : "doc.badge.ellipsis")
                .font(.system(size: 15))
                .foregroundStyle(fileExists ? Color.secondary : Color.red)
                .frame(width: 30, height: 30)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(template.displayName)
                        .font(.callout.weight(.medium))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if !fileExists {
                        statusBadge(L("文件缺失"), color: .red)
                    } else if !template.isVisibleInContextMenu {
                        statusBadge(L("已隐藏"), color: .secondary)
                    }
                }

                Text(template.originalFileName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Menu {
                Button {
                    model.moveCustomTemplate(template.id, direction: .up)
                } label: {
                    Label(L("上移"), systemImage: "arrow.up")
                }
                .disabled(!canMoveUp)

                Button {
                    model.moveCustomTemplate(template.id, direction: .down)
                } label: {
                    Label(L("下移"), systemImage: "arrow.down")
                }
                .disabled(!canMoveDown)

                Divider()

                Button {
                    model.renameCustomTemplate(template.id)
                } label: {
                    Label(L("重命名"), systemImage: "pencil")
                }

                Button(role: .destructive) {
                    model.removeCustomTemplate(template.id)
                } label: {
                    Label(L("删除模板"), systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help(L("更多操作"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .contextMenu {
            Button(L("重命名")) {
                model.renameCustomTemplate(template.id)
            }
            Button(L("上移")) {
                model.moveCustomTemplate(template.id, direction: .up)
            }
            .disabled(!canMoveUp)
            Button(L("下移")) {
                model.moveCustomTemplate(template.id, direction: .down)
            }
            .disabled(!canMoveDown)
            Divider()
            Button(L("删除模板"), role: .destructive) {
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
