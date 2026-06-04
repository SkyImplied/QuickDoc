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
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("自定义文件模板")
                            .font(.headline)
                        Text("按文件类型分别管理模板。每个类型都有自己的上传、显示、排序和隐藏设置。")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Text("\(model.customTemplates.count) 个模板")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.thinMaterial, in: Capsule())
                }

                if model.templateFileTypes.isEmpty {
                    Text("请先添加至少一种带后缀的文件类型。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(alignment: .top, spacing: 18) {
                        templateTypeList
                            .frame(width: 260)

                        Divider()
                            .frame(minHeight: 430)

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

    private var selectedType: TemplateFileType? {
        if let selectedFileTypeID,
           let type = model.templateFileTypes.first(where: { $0.id == selectedFileTypeID }) {
            return type
        }

        return model.templateFileTypes.first
    }

    private var templateTypeList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(model.templateFileTypes) { type in
                Button {
                    selectedFileTypeID = type.id
                } label: {
                    HStack(spacing: 10) {
                        templateIcon(for: type)
                            .frame(width: 20, height: 20)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(type.title)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text(templateSummary(for: type.id))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)

                        if model.customTemplates(for: type.id).count > 0 {
                            Text("\(model.customTemplates(for: type.id).count)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(isSelected(type) ? Color.accentColor : .secondary)
                                .frame(minWidth: 24)
                                .padding(.vertical, 3)
                                .background(.thinMaterial, in: Capsule())
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isSelected(type) ? Color.accentColor.opacity(0.12) : Color.clear)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isSelected(type) ? Color.accentColor.opacity(0.35) : Color.secondary.opacity(0.10), lineWidth: 1)
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func templateTypeDetail(for type: TemplateFileType) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                templateIcon(for: type)
                    .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text(type.title)
                        .font(.title3.weight(.semibold))
                    Text("Finder 右键：新建文件 > \(menuTitle(for: type)) > 模板")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            composer(for: type)

            Divider()

            let templates = model.customTemplates(for: type.id)
            if templates.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("这个类型还没有模板", systemImage: "tray")
                        .font(.callout.weight(.semibold))
                    Text("添加模板后，\(menuTitle(for: type)) 会自动变成三级菜单，里面会先显示空白默认文档，再显示你的模板。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 10)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("显示顺序")
                            .font(.callout.weight(.semibold))
                        Spacer()
                        Text("\(templates.filter(\.isVisibleInContextMenu).count) 个会显示在右键菜单")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

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
    }

    private func composer(for type: TemplateFileType) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Label(selectedTemplateURL?.lastPathComponent ?? "尚未选择 .\(type.pathExtension) 模板", systemImage: "doc")
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    chooseTemplateFile(for: type)
                } label: {
                    Label(selectedTemplateURL == nil ? "选择文件" : "重新选择", systemImage: "folder")
                }
                .glassButtonStyle()
            }

            HStack(spacing: 12) {
                TextField("右键菜单显示名，例如 合同模板", text: $templateDisplayName)
                    .textFieldStyle(.roundedBorder)

                Toggle("显示", isOn: $shouldShowInContextMenu)
                    .toggleStyle(.checkbox)
                    .fixedSize()

                Button {
                    addTemplate(for: type)
                } label: {
                    Label("添加", systemImage: "plus")
                }
                .glassButtonStyle(prominent: true)
                .disabled(!canAddTemplate(for: type))
            }

            Text(addTemplateHint(for: type))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func canAddTemplate(for type: TemplateFileType) -> Bool {
        selectedTemplateURL != nil
            && !templateDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && model.templateFileTypeID(matchingPathExtension: selectedTemplateURL?.pathExtension ?? "") == type.id
    }

    private func addTemplateHint(for type: TemplateFileType) -> String {
        guard let selectedTemplateURL else {
            return "这里只添加 .\(type.pathExtension) 模板，文件会复制到 QuickDoc 的应用支持目录，原文件保留不变。"
        }

        let selectedExtension = selectedTemplateURL.pathExtension.lowercased()
        guard selectedExtension == type.pathExtension else {
            return "当前文件是 .\(selectedExtension.isEmpty ? "无后缀" : selectedExtension)，请为 \(type.title) 选择 .\(type.pathExtension) 文件。"
        }

        return "添加后会出现在 \(menuTitle(for: type)) 的三级菜单里，可继续调整排序或暂时隐藏。"
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
        self.selectedTemplateURL = nil
        templateDisplayName = ""
        shouldShowInContextMenu = true
    }

    private func isSelected(_ type: TemplateFileType) -> Bool {
        selectedType?.id == type.id
    }

    private func templateSummary(for fileTypeID: String) -> String {
        let templates = model.customTemplates(for: fileTypeID)
        guard !templates.isEmpty else { return "无模板" }
        let visibleCount = templates.filter(\.isVisibleInContextMenu).count
        return "\(visibleCount)/\(templates.count) 显示"
    }

    private func menuTitle(for type: TemplateFileType) -> String {
        model.menuTitle(forTemplateFileTypeID: type.id) ?? "新建 \(type.pathExtension.uppercased()) 文件"
    }

    @ViewBuilder
    private func templateIcon(for type: TemplateFileType) -> some View {
        if let image = QuickDocIcon.icon(for: type.id, size: NSSize(width: 20, height: 20)) {
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
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .background(.regularMaterial, in: Circle())

            Toggle("", isOn: Binding(
                get: { template.isVisibleInContextMenu },
                set: { model.setCustomTemplate(template.id, visibleInContextMenu: $0) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(template.displayName)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)

                    if !fileExists {
                        Text("文件缺失")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.12), in: Capsule())
                    } else if !template.isVisibleInContextMenu {
                        Text("暂不显示")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(.thinMaterial, in: Capsule())
                    }
                }

                Text(template.originalFileName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                Button {
                    model.moveCustomTemplate(template.id, direction: .up)
                } label: {
                    Image(systemName: "chevron.up")
                }
                .disabled(!canMoveUp)
                .help("上移")

                Button {
                    model.moveCustomTemplate(template.id, direction: .down)
                } label: {
                    Image(systemName: "chevron.down")
                }
                .disabled(!canMoveDown)
                .help("下移")

                Button {
                    model.renameCustomTemplate(template.id)
                } label: {
                    Image(systemName: "pencil")
                }
                .help("重命名")

                Button(role: .destructive) {
                    model.removeCustomTemplate(template.id)
                } label: {
                    Image(systemName: "trash")
                }
                .help("删除模板")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
