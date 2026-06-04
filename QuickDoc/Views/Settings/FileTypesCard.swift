import SwiftUI

struct FileTypesCard: View {
    @EnvironmentObject private var model: QuickDocSettingsModel
    @State private var customExtension = ""

    private let columns = [
        GridItem(.flexible(minimum: 150), spacing: 12),
        GridItem(.flexible(minimum: 170), spacing: 12),
        GridItem(.flexible(minimum: 170), spacing: 12)
    ]

    var body: some View {
        GlassSection {
            VStack(alignment: .leading, spacing: 18) {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                    ForEach(quickDocFileTypes) { type in
                        Toggle(type.title, isOn: Binding(
                            get: { model.enabledFileTypes.contains(type.id) },
                            set: { model.setFileType(type.id, enabled: $0) }
                        ))
                    }
                }

                Divider()

                HStack(spacing: 12) {
                    Text("自定义后缀")
                        .font(.callout.weight(.medium))
                    TextField("输入扩展名，例如 .yaml", text: $customExtension)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addCustomExtension)
                    Button("添加") {
                        addCustomExtension()
                    }
                    .glassButtonStyle()
                }

                if !model.customExtensions.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], alignment: .leading, spacing: 10) {
                        ForEach(model.customExtensions, id: \.self) { fileExtension in
                            HStack(spacing: 8) {
                                Text(".\(fileExtension)")
                                    .font(.callout.weight(.medium))
                                Button {
                                    model.removeCustomExtension(fileExtension)
                                } label: {
                                    Image(systemName: "xmark")
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.thinMaterial, in: Capsule())
                        }
                    }
                }

                Text("勾选后将显示在 Finder 右键新建菜单中")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func addCustomExtension() {
        guard model.addCustomExtension(customExtension) else { return }
        customExtension = ""
    }
}
