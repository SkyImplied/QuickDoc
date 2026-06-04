import SwiftUI

struct PermissionsPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageHeader(title: "权限与扩展", subtitle: "确认 Finder Sync 扩展已在系统设置中启用。")
            PermissionStatusCard()
        }
    }
}

struct FileTypesPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageHeader(title: "新建文件类型", subtitle: "选择要出现在 Finder 右键菜单里的文件类型，添加自定义后缀，并管理常用文件模板。")
            FileTypesCard()
            CustomTemplatesCard()
            MenuPreviewCard()
        }
    }
}

struct FinderActionsPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageHeader(title: "访达操作", subtitle: "当右键菜单未刷新时，重启 Finder 可强制重新载入扩展。")
            FinderRestartCard()
        }
    }
}
