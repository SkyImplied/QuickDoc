import SwiftUI

struct FileTypesCard: View {
    @EnvironmentObject private var model: QuickDocSettingsModel
    @State private var customExtension = ""
    @FocusState private var isCustomExtensionFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            builtInGroup
            customExtensionGroup
        }
    }

    private var builtInGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsSectionTitle(title: "内置类型", systemImage: "doc.badge.plus")
            GlassSection {
                ViewThatFits(in: .horizontal) {
                    builtInGrid(columnCount: 2)
                        .frame(minWidth: 600)
                    builtInGrid(columnCount: 1)
                }
            }
        }
        .onAppear(perform: applyPreviewExtensionDraft)
    }

    private func applyPreviewExtensionDraft() {
#if SIDEBAR_PREVIEW
        guard customExtension.isEmpty, !model.previewCustomExtensionDraft.isEmpty else { return }
        customExtension = model.previewCustomExtensionDraft
#endif
    }

    private func builtInGrid(columnCount: Int) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 22), count: columnCount), alignment: .leading, spacing: 2) {
            ForEach(quickDocFileTypes) { type in
                builtInRow(type)
            }
        }
    }

    private func builtInRow(_ type: FileType) -> some View {
        let isEnabled = model.enabledFileTypes.contains(type.id)
        return HStack(spacing: 10) {
            fileIcon(for: type)
                .frame(width: 20, height: 20)
            Text(displayName(for: type))
                .font(.body)
                .lineLimit(1)
            Text(type.pathExtension.map { ".\($0)" } ?? "无后缀")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 8)
            Toggle("", isOn: Binding(
                get: { model.enabledFileTypes.contains(type.id) },
                set: { model.setFileType(type.id, enabled: $0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .accessibilityLabel("\(displayName(for: type))，\(isEnabled ? "已启用" : "未启用")")
        }
        .padding(.vertical, 4)
    }

    private var customExtensionGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsSectionTitle(title: "自定义后缀", systemImage: "plus.square.dashed")
            GlassSection {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Text(".")
                                .font(.body.monospaced())
                                .foregroundStyle(.secondary)
                            TextField("后缀，如 yaml", text: $customExtension)
                                .textFieldStyle(.plain)
                                .focused($isCustomExtensionFocused)
                                .onSubmit(addCustomExtension)
                        }
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(fieldStroke, lineWidth: 1)
                        }

                        Button("添加", action: addCustomExtension)
                            .disabled(!canSubmitCustomExtension)
                    }

                    if let validationMessage {
                        Text(validationMessage)
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if model.customExtensions.isEmpty {
                        if validationMessage == nil {
                            Text("尚未添加。添加后自动启用。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(model.customExtensions.enumerated()), id: \.element) { index, fileExtension in
                                if index > 0 {
                                    Divider()
                                }
                                customExtensionRow(fileExtension)
                            }
                        }
                        Text("删除后缀时，该类型下的模板也会移除。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func customExtensionRow(_ fileExtension: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "doc")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
            Text(".\(fileExtension)")
                .font(.body.monospaced())
                .lineLimit(1)
            Spacer(minLength: 8)
            Button(role: .destructive) {
                model.removeCustomExtension(fileExtension)
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .help("删除 .\(fileExtension)")
            .accessibilityLabel("删除 .\(fileExtension)")
        }
        .padding(.vertical, 4)
    }

    private var fieldStroke: Color {
        if validationMessage != nil {
            return Color.orange.opacity(0.7)
        }
        return isCustomExtensionFocused ? Color.accentColor.opacity(0.65) : Color.primary.opacity(0.10)
    }

    private var normalizedCustomExtension: String {
        var normalized = customExtension.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        while normalized.hasPrefix(".") {
            normalized.removeFirst()
        }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789_-+")
        normalized = String(normalized.unicodeScalars.filter { allowed.contains($0) })
        return String(normalized.prefix(24))
    }

    private var validationMessage: String? {
        let normalized = normalizedCustomExtension
        guard !normalized.isEmpty else { return nil }
        if quickDocFileTypes.contains(where: { $0.pathExtension == normalized }) {
            return ".\(normalized) 已在内置类型中。"
        }
        if model.customExtensions.contains(normalized) {
            return ".\(normalized) 已经添加。"
        }
        return nil
    }

    private var canSubmitCustomExtension: Bool {
        !normalizedCustomExtension.isEmpty && validationMessage == nil
    }

    private func addCustomExtension() {
        guard canSubmitCustomExtension else { return }
        guard model.addCustomExtension(customExtension) else { return }
        customExtension = ""
        isCustomExtensionFocused = true
    }

    @ViewBuilder
    private func fileIcon(for type: FileType) -> some View {
        if let image = QuickDocIcon.icon(for: type.id, size: NSSize(width: 18, height: 18)) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "doc")
                .foregroundStyle(.secondary)
        }
    }

    private func displayName(for type: FileType) -> String {
        switch type.id {
        case "txt": return "TXT"
        case "md": return "Markdown"
        case "docx": return "Word"
        case "xlsx": return "Excel"
        case "csv": return "CSV"
        case "pptx": return "PowerPoint"
        case "json": return "JSON"
        case "blank": return "空白文件"
        case "py": return "Python"
        case "html": return "HTML"
        case "sh": return "Shell"
        case "rtf": return "Rich Text"
        default: return type.title
        }
    }
}
