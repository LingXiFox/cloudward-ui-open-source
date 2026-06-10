import CloudwardCore
import SwiftUI

struct MenuBarStatusView: View {
    @Bindable var state: CloudwardAppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("归云", systemImage: state.menuBarSymbolName)
                    .font(.headline)
                    .foregroundStyle(state.menuBarTint)
                Spacer()
                Text(state.syncActivityUpdatedText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("本地占用")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ByteValueText(bytes: state.fileIndex?.localBytes ?? state.localBytesInCurrentRoot, numberSize: 28)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Label(state.menuBarStatusTitle, systemImage: state.menuBarSymbolName)
                    .foregroundStyle(state.menuBarTint)
                if let detail = state.menuBarStatusDetail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Divider()

            Button {
                openWindow(id: "main")
            } label: {
                Label("打开归云", systemImage: "macwindow")
            }

            Button {
                state.presentReleasePreviewFromMenuBar()
            } label: {
                Label("全部归云", systemImage: "icloud.and.arrow.up.fill")
            }
            .disabled(!state.canPrepareRelease)

            Button {
                state.sidebarSelection = .syncStatus
                openWindow(id: "main")
            } label: {
                Label("查看同步状态", systemImage: "arrow.triangle.2.circlepath")
            }
        }
        .padding(14)
        .frame(width: 280)
    }
}
