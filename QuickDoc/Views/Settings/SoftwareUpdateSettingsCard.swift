import SwiftUI

struct SoftwareUpdateSettingsCard: View {
    @EnvironmentObject private var model: QuickDocSettingsModel

    var body: some View {
        GlassSection {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 40, height: 40)
                        .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("软件更新")
                            .font(.headline)
                        Text("当前版本 v\(model.appVersion)")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(model.softwareUpdateButtonTitle) {
                        model.checkForSoftwareUpdate()
                    }
                    .disabled(model.isSoftwareUpdateInProgress)
                    .glassButtonStyle(prominent: true)
                }

                if model.isSoftwareUpdateInProgress {
                    ProgressView()
                        .controlSize(.small)
                }

                Text(model.softwareUpdateStatusText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
