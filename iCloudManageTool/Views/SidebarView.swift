import CloudwardCore
import SwiftUI

struct SidebarView: View {
    @Bindable var state: CloudwardAppState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
                .frame(height: 18)

            SidebarSection(title: "位置") {
                if state.containers.isEmpty {
                    SidebarRow(
                        title: "未找到 iCloud 容器",
                        systemImage: "icloud.slash",
                        isSelected: false
                    ) {
                    }
                    .foregroundStyle(.secondary)
                }

                ForEach(state.containers) { container in
                    SidebarRow(
                        title: container.name,
                        systemImage: iconName(for: container),
                        help: container.tooltip,
                        isSelected: state.sidebarSelection == .container(container.id)
                    ) {
                        state.sidebarSelection = .container(container.id)
                        state.loadCurrentRootIfNeeded()
                    }
                }
            }

            SidebarSection(title: "扫描中心") {
                SidebarRow(title: "空间分析", systemImage: "chart.pie", isSelected: state.sidebarSelection == .spaceAnalysis) {
                    state.sidebarSelection = .spaceAnalysis
                    state.startIndexScanIfNeeded()
                }
                SidebarRow(title: "大文件", systemImage: "list.bullet.rectangle", isSelected: state.sidebarSelection == .largeFiles) {
                    state.sidebarSelection = .largeFiles
                }
                SidebarRow(title: "沉睡文件", systemImage: "moon.fill", isSelected: state.sidebarSelection == .staleFiles) {
                    state.sidebarSelection = .staleFiles
                }
                SidebarRow(title: "可疑冗余", systemImage: "square.on.square", isSelected: state.sidebarSelection == .redundantFiles) {
                    state.sidebarSelection = .redundantFiles
                }
            }

            Divider()
                .padding(.horizontal, 16)

            VStack(spacing: 6) {
                SidebarRow(
                    title: "同步状态",
                    systemImage: "arrow.triangle.2.circlepath",
                    badge: "3",
                    isSelected: state.sidebarSelection == .syncStatus
                ) {
                    state.sidebarSelection = .syncStatus
                }
                SidebarRow(title: "历史", systemImage: "clock", isSelected: state.sidebarSelection == .history) {
                    state.sidebarSelection = .history
                }
            }
            .padding(.horizontal, 12)

            Spacer()
        }
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                LinearGradient(
                    colors: [
                        CloudwardColors.celadon.opacity(0.18),
                        CloudwardColors.moonWhite.opacity(0.06),
                        CloudwardColors.amber.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    private func iconName(for container: CloudContainer) -> String {
        switch container.kind {
        case .iCloudDrive:
            "icloud"
        case .appContainer:
            "shippingbox"
        }
    }
}

private struct SidebarSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            VStack(spacing: 6) {
                content
            }
            .padding(.horizontal, 12)
        }
    }
}

private struct SidebarRow: View {
    let title: String
    let systemImage: String
    var badge: String?
    var help: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 18)
                    .foregroundStyle(isSelected ? CloudwardColors.celadon : .secondary)

                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(CloudwardColors.inkBlue)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                if let badge {
                    Text(badge)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(CloudwardColors.cloudGray, in: Capsule())
                }
            }
            .padding(.horizontal, 9)
            .frame(height: 30)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(CloudwardColors.celadon.opacity(0.18))
                }
            }
        }
        .buttonStyle(.plain)
        .help(help ?? title)
    }
}
