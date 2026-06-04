import SwiftUI

struct QuickDocSettingsView: View {
    @ObservedObject private var model: QuickDocSettingsModel
    @State private var selection: SettingsPage? = .general
    private let sidebarWidth: CGFloat = 282
    private let detailMinWidth: CGFloat = 760

    init(model: QuickDocSettingsModel) {
        _model = ObservedObject(wrappedValue: model)
    }

    var body: some View {
        ZStack(alignment: .top) {
            HStack(spacing: 0) {
                sidebar
                    .frame(width: sidebarWidth)
                    .fixedSize(horizontal: true, vertical: false)
                Divider()
                ScrollView {
                    selectedPage
                        .padding(.horizontal, 36)
                        .padding(.vertical, 30)
                        .frame(maxWidth: 1020, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .frame(minWidth: detailMinWidth, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .scrollContentBackground(.hidden)
                .background(GlassBackground())
            }

            Color.clear
                .frame(height: 58)
                .contentShape(Rectangle())
                .ifAvailableWindowDragGesture()
        }
        .frame(minWidth: sidebarWidth + detailMinWidth + 1, minHeight: 700)
        .environmentObject(model)
    }

    private var sidebar: some View {
        ZStack {
            GlassBackground()

            VStack(spacing: 18) {
                VStack(spacing: 10) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 74, height: 74)
                        .shadow(radius: 8, y: 4)

                    Text("QuickDoc")
                        .font(.title2.weight(.bold))

                    Text("版本 \(model.appVersion)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 28)
                .padding(.bottom, 12)

                List(SettingsPage.allCases, selection: $selection) { page in
                    Label(page.title, systemImage: page.systemImage)
                        .font(.body.weight(.medium))
                        .tag(page)
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
    }

    @ViewBuilder
    private var selectedPage: some View {
        switch selection ?? .general {
        case .general:
            GeneralSettingsPage()
        case .permissions:
            PermissionsPage()
        case .fileTypes:
            FileTypesPage()
        case .finder:
            FinderActionsPage()
        case .about:
            AboutPage()
        }
    }
}
