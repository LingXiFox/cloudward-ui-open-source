import AppKit
import CloudwardCore
import SwiftUI

struct FileTreeRow: View, Equatable {
    let model: FileTreeRowModel
    let onToggleReleaseSelection: () -> Void
    let onToggleExpansion: () -> Void
    let onSelect: () -> Void
    let onPresentRelease: () -> Void
    let onDetectLock: () -> Void

    static func == (lhs: FileTreeRow, rhs: FileTreeRow) -> Bool {
        lhs.model == rhs.model
    }

    var body: some View {
        Group {
            if model.ref.isSkeleton {
                SkeletonFileRow(depth: model.ref.depth)
            } else {
                FileRowLabel(
                    model: model,
                    onToggleReleaseSelection: onToggleReleaseSelection,
                    onToggleExpansion: onToggleExpansion,
                    onSelect: onSelect
                )
                .contextMenu {
                    RowContextMenu(
                        ref: model.ref,
                        onPresentRelease: onPresentRelease,
                        onDetectLock: onDetectLock
                    )
                }
            }
        }
    }
}

private struct FileRowLabel: View {
    let model: FileTreeRowModel
    let onToggleReleaseSelection: () -> Void
    let onToggleExpansion: () -> Void
    let onSelect: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Button {
                onToggleReleaseSelection()
            } label: {
                Image(systemName: model.selectionState.symbolName)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(checkboxColor)
                    .font(.system(size: 15, weight: .semibold))
            }
            .buttonStyle(.plain)
            .frame(width: 24, height: 24)
            .contentShape(Rectangle())
            .symbolEffect(.bounce, value: model.selectionState)

            disclosureControl

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    ZStack {
                        if model.isRippling {
                            CloudRippleView(reduceMotion: reduceMotion)
                        }
                        Image(systemName: iconName)
                            .foregroundStyle(iconColor)
                            .frame(width: 18)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .frame(width: 28, height: 28)

                    Text(model.ref.name)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(localSizeText)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 104, alignment: .trailing)

                StatusBadge(
                    status: model.ref.cloudStatus,
                    directoryCounts: model.ref.directoryCounts,
                    isPendingDirectorySummary: isDirectorySummaryPending
                )
                    .frame(width: 110, alignment: .leading)

                OccupancyIndicator(lockState: model.lockState, cloudStatus: model.ref.cloudStatus)
                    .frame(width: 36)
            }
            .contentShape(Rectangle())
            .overlay {
                ClickGestureBridge {
                    onSelect()
                } onDoubleClick: {
                    guard model.ref.isDirectory else {
                        return
                    }

                    onToggleExpansion()
                }
            }
        }
        .padding(.leading, CGFloat(model.ref.depth) * 18 + 14)
        .padding(.trailing, 14)
        .frame(height: 32)
        .contentShape(Rectangle())
        .background {
            if model.isSelected {
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
        .animation(reduceMotion ? .default : Motion.standard, value: model.ref.cloudStatus)
    }

    @ViewBuilder
    private var disclosureControl: some View {
        if model.ref.isDirectory {
            Button {
                onToggleExpansion()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .rotationEffect(.degrees(model.isExpanded ? 90 : 0))
                    .animation(reduceMotion ? nil : Motion.standard, value: model.isExpanded)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .help(model.isExpanded ? "折叠" : "展开")
        } else {
            Color.clear.frame(width: 24, height: 24)
        }
    }

    private var checkboxColor: Color {
        switch model.selectionState {
        case .none:
            CloudwardColors.cloudGray
        case .partial, .selected:
            CloudwardColors.celadon
        }
    }

    private var iconName: String {
        if model.ref.cloudStatus == .evicted || model.ref.cloudStatus == .allEvicted {
            return "icloud"
        }

        return model.ref.isDirectory ? "folder.fill" : "doc.fill"
    }

    private var iconColor: Color {
        if model.ref.cloudStatus == .evicted || model.ref.cloudStatus == .allEvicted {
            return CloudwardColors.cloudGray
        }

        return model.ref.isDirectory ? CloudwardColors.celadon : CloudwardColors.inkBlue
    }

    private var localSizeText: String {
        isDirectorySummaryPending ? "计算中…" : model.ref.localAllocatedBytes.cloudwardBytes
    }

    private var isDirectorySummaryPending: Bool {
        model.ref.isDirectory && model.ref.directoryCounts == nil && model.ref.cloudStatus == .unknown
    }
}

private struct OccupancyIndicator: View {
    let lockState: NodeLockState
    let cloudStatus: CloudStatus

    var body: some View {
        Group {
            if cloudStatus.showsNoOccupancy {
                Text("—")
                    .foregroundStyle(.secondary.opacity(0.5))
            } else if lockState.isChecking {
                Image(systemName: "clock")
                    .foregroundStyle(CloudwardColors.cloudGray)
            } else if cloudStatus.isSyncBlocked {
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

private extension CloudStatus {
    var showsNoOccupancy: Bool {
        switch self {
        case .evicted, .allEvicted, .empty:
            true
        case .localCopy, .uploading, .notUploaded, .downloading, .conflict, .unknown, .allLocal, .partiallyLocal:
            false
        }
    }
}

private struct StatusBadge: View {
    let status: CloudStatus
    var directoryCounts: DirectoryCloudCounts?
    var isPendingDirectorySummary = false

    var body: some View {
        Group {
            if isPendingDirectorySummary {
                Label(title, systemImage: "clock")
            } else if status == .empty {
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
        if isPendingDirectorySummary {
            return "计算中…"
        }

        return status.displayName
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
        if isPendingDirectorySummary {
            return .secondary
        }

        switch status {
        case .localCopy, .allLocal, .partiallyLocal:
            return CloudwardColors.celadon
        case .evicted, .allEvicted, .empty:
            return CloudwardColors.cloudGray
        case .uploading, .notUploaded, .conflict:
            return CloudwardColors.amber
        case .downloading, .unknown:
            return .secondary
        }
    }
}

private struct RowContextMenu: View {
    let ref: NodeRef
    let onPresentRelease: () -> Void
    let onDetectLock: () -> Void

    var body: some View {
        Button {
            if let url = ref.url {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
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
            onPresentRelease()
        } label: {
            Label("立即释放", systemImage: "icloud.and.arrow.up")
        }
        .disabled(ref.localAllocatedBytes <= 0)

        Button {
            onDetectLock()
        } label: {
            Label("检测占用", systemImage: "lock")
        }
    }
}
