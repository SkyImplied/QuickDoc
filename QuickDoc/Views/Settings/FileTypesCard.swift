import SwiftUI

struct FileTypesCard: View {
    @EnvironmentObject private var model: QuickDocSettingsModel
    @State private var customExtension = ""
    @FocusState private var isCustomExtensionFocused: Bool

    private let columns = [
        GridItem(.flexible(minimum: 180), spacing: 12),
        GridItem(.flexible(minimum: 180), spacing: 12),
        GridItem(.flexible(minimum: 180), spacing: 12)
    ]

    var body: some View {
        GlassSection {
            VStack(alignment: .leading, spacing: 20) {
                sectionHeader
                builtInTypesGrid
                Divider()
                customExtensionsSection
            }
        }
    }

    private var sectionHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 42, height: 42)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("内置文件类型")
                    .font(.headline)
                Text("点击文件类型即可决定它是否出现在 Finder 的“新建文件”菜单中。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 16)

            Label("\(enabledBuiltInCount) / \(quickDocFileTypes.count) 已启用", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.10), in: Capsule())
        }
    }

    private var builtInTypesGrid: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            ForEach(quickDocFileTypes) { type in
                FileTypeToggleCard(
                    type: type,
                    isEnabled: model.enabledFileTypes.contains(type.id)
                ) {
                    let isEnabled = model.enabledFileTypes.contains(type.id)
                    withAnimation(.easeInOut(duration: 0.16)) {
                        model.setFileType(type.id, enabled: !isEnabled)
                    }
                }
            }
        }
    }

    private var customExtensionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "plus.square.dashed")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 36, height: 36)
                    .background(Color.accentColor.opacity(0.09), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("自定义文件后缀")
                        .font(.callout.weight(.semibold))
                    Text("添加内置列表之外的文件类型，例如 YAML、LOG 或 TOML。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !model.customExtensions.isEmpty {
                    Text("\(model.customExtensions.count) 个自定义类型")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Text(".")
                        .font(.body.monospaced().weight(.semibold))
                        .foregroundStyle(.secondary)

                    TextField("输入后缀，例如 yaml", text: $customExtension)
                        .textFieldStyle(.plain)
                        .focused($isCustomExtensionFocused)
                        .onSubmit(addCustomExtension)
                }
                .padding(.horizontal, 11)
                .frame(height: 36)
                .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(isCustomExtensionFocused ? Color.accentColor.opacity(0.65) : Color.primary.opacity(0.10), lineWidth: 1)
                }

                Button {
                    addCustomExtension()
                } label: {
                    Label("添加后缀", systemImage: "plus")
                }
                .glassButtonStyle(prominent: canSubmitCustomExtension)
                .disabled(!canSubmitCustomExtension)
            }

            if model.customExtensions.isEmpty {
                Label("尚未添加自定义后缀", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 170), spacing: 9)],
                    alignment: .leading,
                    spacing: 9
                ) {
                    ForEach(model.customExtensions, id: \.self) { fileExtension in
                        CustomExtensionPill(fileExtension: fileExtension) {
                            model.removeCustomExtension(fileExtension)
                        }
                    }
                }
            }

            Label("自定义类型添加后会自动启用，并可继续添加对应的文件模板。", systemImage: "lightbulb")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private var enabledBuiltInCount: Int {
        quickDocFileTypes.reduce(into: 0) { count, type in
            if model.enabledFileTypes.contains(type.id) {
                count += 1
            }
        }
    }

    private var canSubmitCustomExtension: Bool {
        !customExtension.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func addCustomExtension() {
        guard model.addCustomExtension(customExtension) else { return }
        customExtension = ""
        isCustomExtensionFocused = true
    }
}

private struct FileTypeToggleCard: View {
    let type: FileType
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                fileIcon
                    .frame(width: 36, height: 36)
                    .background(
                        isEnabled ? Color.accentColor.opacity(0.11) : Color.primary.opacity(0.045),
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(displayName)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(type.pathExtension.map { ".\($0.lowercased())" } ?? "无扩展名")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 6)

                Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isEnabled ? Color.accentColor : Color.secondary.opacity(0.48))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isEnabled ? Color.accentColor.opacity(0.075) : Color.primary.opacity(0.022),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isEnabled ? Color.accentColor.opacity(0.22) : Color.primary.opacity(0.075), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(displayName)，\(isEnabled ? "已启用" : "未启用")")
        .accessibilityHint("点击以\(isEnabled ? "从" : "添加到") Finder 新建文件菜单")
    }

    @ViewBuilder
    private var fileIcon: some View {
        if let image = QuickDocIcon.icon(for: type.id, size: NSSize(width: 24, height: 24)) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
        } else {
            Image(systemName: "doc")
                .font(.system(size: 17))
                .foregroundStyle(.secondary)
        }
    }

    private var displayName: String {
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

private struct CustomExtensionPill: View {
    let fileExtension: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "doc.text")
                .foregroundStyle(Color.accentColor)

            Text(".\(fileExtension.lowercased())")
                .font(.callout.monospaced().weight(.semibold))

            Spacer(minLength: 4)

            Button(role: .destructive, action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("删除 .\(fileExtension) 类型")
        }
        .padding(.horizontal, 11)
        .frame(height: 36)
        .background(Color.accentColor.opacity(0.055), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.accentColor.opacity(0.13), lineWidth: 1)
        }
    }
}
