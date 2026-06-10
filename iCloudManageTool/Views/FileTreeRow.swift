import AppKit
import CloudwardCore
import SwiftUI

struct FileTreeRow: View {
    @Bindable var state: CloudwardAppState
    let node: FileNode
    var depth = 0

    var body: some View {
        VStack(spacing: 0) {
            FileRowLabel(state: state, node: node, depth: depth)
                .contextMenu {
                    RowContextMenu(state: state, node: node)
                }

            if node.isDirectory, state.expandedDirectories.contains(node.url) {
                if state.loadingDirectories.contains(node.url),
                   state.childrenByParent[node.url] == nil {
                    ForEach(0..<4, id: \.self) { _ in
                        SkeletonFileRow(depth: depth + 1)
                    }
                }

                ForEach(state.children(of: node.url)) { child in
                    FileTreeRow(state: state, node: child, depth: depth + 1)
                }
            }
        }
    }
}

private struct FileRowLabel: View {
    @Bindable var state: CloudwardAppState
    let node: FileNode
    let depth: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Button {
                state.toggleReleaseSelection(for: node)
            } label: {
                Image(systemName: state.releaseSelectionState(for: node).symbolName)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(checkboxColor)
                    .font(.system(size: 15, weight: .semibold))
            }
            .buttonStyle(.plain)
            .frame(width: 24, height: 24)
            .contentShape(Rectangle())
            .symbolEffect(.bounce, value: state.releaseSelectionState(for: node))

            disclosureControl

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    ZStack {
                        CloudRippleView(isActive: node.cloudStatus == .evicted || node.cloudStatus == .allEvicted, reduceMotion: reduceMotion)
                        Image(systemName: iconName)
                            .foregroundStyle(iconColor)
                            .frame(width: 18)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .frame(width: 28, height: 28)

                    Text(node.name)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(node.localAllocatedBytes.cloudwardBytes)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 104, alignment: .trailing)

                StatusBadge(status: node.cloudStatus, directoryCounts: node.directoryCounts)
                    .frame(width: 110, alignment: .leading)

                OccupancyIndicator(lockState: lockState, isSyncBlocked: node.cloudStatus.isSyncBlocked)
                    .frame(width: 36)
            }
            .contentShape(Rectangle())
            .overlay {
                ClickGestureBridge {
                    state.selectNode(node)
                } onDoubleClick: {
                    guard node.isDirectory else {
                        return
                    }

                    state.setExpanded(!state.expandedDirectories.contains(node.url), for: node.url)
                }
            }
        }
        .padding(.leading, CGFloat(depth) * 18 + 14)
        .padding(.trailing, 14)
        .frame(height: 32)
        .contentShape(Rectangle())
        .background {
            if state.selectedNode?.id == node.id {
                CloudwardColors.selectedRow
            } else if isHovered {
                CloudwardColors.rowHover
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(CloudwardColors.separator.opacity(0.72))
                .frame(height: 0.5)
        }
        .onHover { isHovered = $0 }
        .animation(reduceMotion ? .default : Motion.standard, value: isHovered)
        .animation(reduceMotion ? .default : Motion.standard, value: node.cloudStatus)
    }

    @ViewBuilder
    private var disclosureControl: some View {
        if node.isDirectory {
            Button {
                state.setExpanded(!state.expandedDirectories.contains(node.url), for: node.url)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .rotationEffect(.degrees(state.expandedDirectories.contains(node.url) ? 90 : 0))
                    .animation(reduceMotion ? nil : Motion.standard, value: state.expandedDirectories.contains(node.url))
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .help(state.expandedDirectories.contains(node.url) ? "折叠" : "展开")
        } else {
            Color.clear.frame(width: 24, height: 24)
        }
    }

    private var checkboxColor: Color {
        switch state.releaseSelectionState(for: node) {
        case .none:
            CloudwardColors.cloudGray
        case .partial, .selected:
            CloudwardColors.celadon
        }
    }

    private var iconName: String {
        if node.cloudStatus == .evicted || node.cloudStatus == .allEvicted {
            return "icloud"
        }

        return node.isDirectory ? "folder.fill" : "doc.fill"
    }

    private var iconColor: Color {
        if node.cloudStatus == .evicted || node.cloudStatus == .allEvicted {
            return CloudwardColors.cloudGray
        }

        return node.isDirectory ? CloudwardColors.celadon : CloudwardColors.inkBlue
    }

    private var lockState: NodeLockState {
        state.lockState(for: node)
    }

}

private struct OccupancyIndicator: View {
    let lockState: NodeLockState
    let isSyncBlocked: Bool

    var body: some View {
        Group {
            if lockState.isChecking {
                Image(systemName: "clock")
                    .foregroundStyle(CloudwardColors.cloudGray)
            } else if isSyncBlocked {
                Image(systemName: "lock.fill")
                    .foregroundStyle(CloudwardColors.amber)
            } else {
                switch lockState.semanticState {
                case .unknown:
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .foregroundStyle(Color.secondary.opacity(0.18))
                        .frame(width: 16, height: 16)
                case .locked:
                    Image(systemName: "lock.fill")
                        .foregroundStyle(CloudwardColors.amber)
                        .symbolEffect(.wiggle, value: true)
                case .unlocked:
                    Image(systemName: "lock.open")
                        .foregroundStyle(Color.secondary.opacity(0.45))
                }
            }
        }
        .transition(.opacity)
        .animation(Motion.standard, value: lockState.semanticState)
    }
}

private struct StatusBadge: View {
    let status: CloudStatus
    var directoryCounts: DirectoryCloudCounts?

    var body: some View {
        Group {
            if status == .empty {
                Text(title)
            } else {
                Label(title, systemImage: symbolName)
            }
        }
        .font(.caption)
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(color.opacity(0.12), in: Capsule())
        .lineLimit(1)
        .help(directoryCounts?.tooltipText ?? title)
    }

    private var title: String {
        status.displayName
    }

    private var symbolName: String {
        switch status {
        case .localCopy:
            "externaldrive.fill"
        case .evicted, .allEvicted:
            "icloud"
        case .uploading:
            "arrow.up.circle"
        case .notUploaded:
            "exclamationmark.icloud"
        case .downloading:
            "arrow.down.circle"
        case .conflict:
            "exclamationmark.triangle"
        case .unknown:
            "questionmark.circle"
        case .empty:
            "minus"
        case .allLocal:
            "externaldrive.fill"
        case .partiallyLocal:
            "icloud.and.arrow.down"
        }
    }

    private var color: Color {
        switch status {
        case .localCopy, .allLocal, .partiallyLocal:
            CloudwardColors.celadon
        case .evicted, .allEvicted, .empty:
            CloudwardColors.cloudGray
        case .uploading, .notUploaded, .conflict:
            CloudwardColors.amber
        case .downloading, .unknown:
            .secondary
        }
    }
}

private struct RowContextMenu: View {
    var state: CloudwardAppState
    let node: FileNode

    var body: some View {
        Button {
            NSWorkspace.shared.activateFileViewerSelecting([node.url])
        } label: {
            Label("在访达中显示", systemImage: "finder")
        }

        Button {
        } label: {
            Label("快速查看", systemImage: "eye")
        }
        .disabled(true)

        Divider()

        Button {
            state.presentReleasePreview(for: node)
        } label: {
            Label("立即释放", systemImage: "icloud.and.arrow.up")
        }
        .disabled(node.localAllocatedBytes <= 0)

        Button {
            state.detectLock(for: node)
        } label: {
            Label("检测占用", systemImage: "lock")
        }
    }
}
