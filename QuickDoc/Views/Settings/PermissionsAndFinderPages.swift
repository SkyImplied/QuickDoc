import SwiftUI

struct PermissionsPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageHeader(title: "权限与扩展")
            PermissionStatusCard()
            PermissionWalkthroughCard()
        }
    }
}

struct FileTypesPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(title: "新建文件类型")
            FileTypesCard()
            CustomTemplatesCard()
            MenuPreviewCard()
        }
    }
}

struct FinderActionsPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageHeader(title: "访达操作")
            FinderRestartCard()
            FinderExperienceDemoCard()
        }
    }
}
