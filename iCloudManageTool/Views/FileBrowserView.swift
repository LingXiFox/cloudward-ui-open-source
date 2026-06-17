import CloudwardCore
import SwiftUI

struct FileBrowserView: View {
    @Bindable var state: CloudwardAppState

    var body: some View {
        Group {
            switch state.sidebarSelection {
            case .container:
                if let rootURL = state.currentRootURL {
                    FileTreeContentView(state: state, rootURL: rootURL)
                } else {
                    PlaceholderPage(
                        symbolName: placeholderSymbol,
                        title: state.currentTitle,
                        message: placeholderMessage
                    )
                }
            case .syncStatus:
                SyncStatusView(state: state)
            case .spaceAnalysis:
                ExpandedDashboardCard(state: state)
                    .padding(16)
                    .background(CloudwardColors.moonWhite)
            case .largeFiles, .staleFiles, .redundantFiles:
                ScanCenterView(state: state, selection: state.sidebarSelection ?? .largeFiles)
            case .history:
                HistoryView()
            default:
                PlaceholderPage(
                    symbolName: placeholderSymbol,
                    title: state.currentTitle,
                    message: placeholderMessage
                )
            }
        }
        .task(id: state.currentRootURL) {
            state.loadCurrentRootIfNeeded()
        }
    }

    private var placeholderSymbol: String {
        switch state.sidebarSelection {
        case .spaceAnalysis:
            "chart.pie"
        case .largeFiles:
            "internaldrive"
        case .staleFiles:
            "moon"
        case .redundantFiles:
            "doc.badge.gearshape"
        case .syncStatus:
            "icloud.and.arrow.up"
        case .history:
            "clock.arrow.circlepath"
        case .container, nil:
            "icloud.slash"
        }
    }

    private var placeholderMessage: String {
        if let lastError = state.lastError {
            return lastError
        }

        switch state.sidebarSelection {
        case .spaceAnalysis:
            return "空间分析需要完成一次索引扫描。"
        case .largeFiles, .staleFiles, .redundantFiles:
            return "扫描中心将在 M4 接入统一索引。"
        case .syncStatus:
            return "同步仪表将在 M3 接入元数据监听。"
        case .history:
            return "释放历史将在 M5 接入 SwiftData。"
        case .container, nil:
            return "登录并开启 iCloud Drive 后再试。"
        }
    }
}

private struct FileTreeContentView: View {
    @Bindable var state: CloudwardAppState
    let rootURL: URL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 12) {
                        CompactOverviewCard(state: state)

                        FilterBar(state: state)

                        FileTableCard(state: state, rootURL: rootURL)
                    }
                    .padding(16)
                }

                if state.releaseSelection.isEmpty == false {
                    SelectionActionBar(state: state)
                        .padding(.bottom, 18)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            InspectorView(state: state)
                .frame(width: 264)
                .background(CloudwardColors.panel.opacity(0.72))
        }
        .focusEffectDisabled()
        .onMoveCommand { direction in
            guard let selectedNode = state.selectedNode, selectedNode.isDirectory else {
                return
            }

            switch direction {
            case .right:
                state.setExpanded(true, for: selectedNode.url)
            case .left:
                state.setExpanded(false, for: selectedNode.url)
            default:
                break
            }
        }
        .animation(reduceMotion ? nil : Motion.standard, value: state.releaseSelection)
    }
}

private struct CompactOverviewCard: View {
    var state: CloudwardAppState
    @Environment(\.openSettings) private var openSettings
    @AppStorage("icloudPlanCapacityBytes") private var storedPlanCapacityBytes = ""
    @AppStorage("icloudPlanCapacityHintDismissed") private var capacityHintDismissed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("本地占用")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ByteValueText(bytes: state.localBytesInCurrentRoot)
                    HStack(spacing: 8) {
                        Text(overviewText)
                            .font(.caption)
                            .foregroundStyle(CloudwardColors.celadon)
                            .lineLimit(1)
                            .help(overviewHelp)

                        if let snapshotAgeText = state.snapshotAgeText {
                            Text(snapshotAgeText)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(CloudwardColors.inkBlue)
                                .lineLimit(1)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(CloudwardColors.panel, in: Capsule())
                                .help("正在用上次快照显示文件树，最新索引完成后会自动调和")
                        }

                        if shouldShowCapacityHint {
                            Button("设置套餐容量") {
                                openSettings()
                            }
                            .buttonStyle(.plain)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(CloudwardColors.celadon)
                            .help("容量为手动设置,可在设置中修改")

                            Button {
                                capacityHintDismissed = true
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("不再提示")
                        }
                    }
                }

                UsageStackedBar(stats: state.usageCategoryStats)
                    .frame(maxWidth: .infinity)

                Button {
                    state.sidebarSelection = .spaceAnalysis
                    state.startIndexScanIfNeeded()
                } label: {
                    Image(systemName: "chart.pie")
                        .frame(width: 32, height: 32)
                        .background(CloudwardColors.panel, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .help("查看空间分析")
            }

            if state.fileBrowserShowsStatusBanner {
                IndexProgressStrip(
                    title: state.fileBrowserStatusTitle,
                    detail: state.fileBrowserStatusDetail,
                    showsProgress: state.fileBrowserShowsProgress
                )
            }
        }
        .padding(16)
        .background(CloudwardColors.card, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 12, y: 5)
        .contentShape(Rectangle())
        .onTapGesture {
            state.sidebarSelection = .spaceAnalysis
            state.startIndexScanIfNeeded()
        }
        .task {
            state.refreshICloudQuotaIfNeeded()
        }
    }

    private var planCapacityBytes: Int64? {
        guard let bytes = Int64(storedPlanCapacityBytes), bytes > 0 else {
            return nil
        }

        return bytes
    }

    private var overviewText: String {
        let releasable = "本机可释放约 \(state.releasableBytesInCurrentRoot.cloudwardBytes)"
        guard let planCapacityBytes else {
            return releasable
        }

        if let remaining = state.iCloudRemainingQuotaBytes {
            let used = planCapacityBytes - remaining
            if used >= 0 {
                return "iCloud 共 \(planCapacityBytes.cloudwardBytes) · 全账户已用约 \(used.cloudwardBytes) · \(releasable)"
            }
        }

        return "iCloud 共 \(planCapacityBytes.cloudwardBytes) · \(releasable)"
    }

    private var overviewHelp: String {
        planCapacityBytes == nil
            ? "可在设置中填写 iCloud 套餐容量"
            : "容量为手动设置,可在设置中修改"
    }

    private var shouldShowCapacityHint: Bool {
        planCapacityBytes == nil && capacityHintDismissed == false
    }
}

private struct IndexProgressStrip: View {
    let title: String
    let detail: String
    let showsProgress: Bool

    var body: some View {
        HStack(spacing: 10) {
            if showsProgress {
                ProgressView()
                    .controlSize(.small)
                    .tint(CloudwardColors.celadon)
            } else {
                Image(systemName: "exclamationmark.magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(CloudwardColors.amber)
                    .frame(width: 16)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CloudwardColors.inkBlue)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(CloudwardColors.panel.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct UsageStackedBar: View {
    let stats: [UsageCategoryStat]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                let visibleStats = normalizedStats(for: proxy.size.width)
                HStack(spacing: 2) {
                    ForEach(visibleStats) { stat in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(stat.category.color)
                            .frame(width: stat.width)
                    }
                }
            }
            .frame(height: 10)
            .clipShape(Capsule())

            HStack(spacing: 12) {
                let nonZeroStats = stats.filter { $0.bytes > 0 }
                if nonZeroStats.isEmpty {
                    Text("暂无本地占用")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(nonZeroStats) { stat in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(stat.category.color)
                                .frame(width: 7, height: 7)
                            Text(stat.category.title)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func normalizedStats(for width: CGFloat) -> [VisibleUsageStat] {
        let nonZero = stats.filter { $0.bytes > 0 }
        let source = nonZero
        guard source.isEmpty == false else {
            return []
        }
        let count = max(source.count, 1)
        let spacing = CGFloat(max(count - 1, 0)) * 2
        let usableWidth = max(width - spacing, 0)
        let total = max(source.reduce(Double(0)) { $0 + max($1.fraction, 0.025) }, 0.001)

        return source.map { stat in
            VisibleUsageStat(
                category: stat.category,
                width: usableWidth * max(stat.fraction, 0.025) / total
            )
        }
    }
}

private struct VisibleUsageStat: Identifiable {
    let category: UsageCategory
    let width: CGFloat
    var id: UsageCategory.ID { category.id }
}

private struct FilterBar: View {
    @Bindable var state: CloudwardAppState

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("搜索文件或目录", text: $state.searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 10)
            .frame(width: 240, height: 30)
            .background(CloudwardColors.card, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(CloudwardColors.separator))

            FilterPill("全部", isSelected: !state.showLocalCopiesOnly && state.minimumSizeFilter == .any) {
                state.showLocalCopiesOnly = false
                state.minimumSizeFilter = .any
            }
            FilterPill("> 1 GB", isSelected: state.minimumSizeFilter == .oneGB) {
                state.minimumSizeFilter = .oneGB
            }
            FilterPill("90 天未访问", isSelected: false) {
            }
            FilterPill("仅本地占用", isSelected: state.showLocalCopiesOnly) {
                state.showLocalCopiesOnly.toggle()
            }

            Spacer()

            Menu {
                ForEach(FileSortOrder.allCases) { order in
                    Button(order.title) {
                        state.sortOrder = order
                    }
                }
            } label: {
                Label("按大小排序", systemImage: "chevron.down")
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
        }
    }
}

private struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    init(_ title: String, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 14)
                .frame(height: 30)
                .foregroundStyle(isSelected ? .white : CloudwardColors.inkBlue)
                .background(isSelected ? CloudwardColors.inkBlue : CloudwardColors.card, in: Capsule())
                .overlay(Capsule().stroke(isSelected ? Color.clear : CloudwardColors.separator))
        }
        .buttonStyle(.plain)
    }
}

private struct FileTableCard: View {
    @Bindable var state: CloudwardAppState
    let rootURL: URL

    var body: some View {
        VStack(spacing: 0) {
            FileListHeader()
                .padding(.horizontal, 14)
                .frame(height: 32)
                .background(CloudwardColors.card)

            Divider()

            LazyVStack(spacing: 0) {
                ForEach(state.visibleRows) { row in
                    FileTreeRow(
                        model: row,
                        onToggleReleaseSelection: {
                            state.toggleReleaseSelection(forNodeID: row.id)
                        },
                        onToggleExpansion: {
                            state.toggleExpanded(forNodeID: row.id)
                        },
                        onSelect: {
                            state.selectNode(id: row.id)
                        },
                        onPresentRelease: {
                            state.presentReleasePreview(forNodeID: row.id)
                        },
                        onDetectLock: {
                            state.detectLock(forNodeID: row.id)
                        }
                    )
                    .equatable()
                    .onAppear {
                        state.visibleRowAppeared(id: row.id)
                    }
                    .onDisappear {
                        state.visibleRowDisappeared(id: row.id)
                    }
                }

                if state.visibleRows.isEmpty {
                    FileTableEmptyState(
                        title: state.fileBrowserStatusTitle,
                        detail: state.fileBrowserStatusDetail,
                        showsProgress: state.fileBrowserShowsProgress,
                        onRetry: {
                            state.reloadCurrentRoot()
                            state.startIndexScan()
                        }
                    )
                }
            }
        }
        .background(CloudwardColors.card, in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
    }
}

private struct FileTableEmptyState: View {
    let title: String
    let detail: String
    let showsProgress: Bool
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            if showsProgress {
                ProgressView()
                    .controlSize(.small)
                    .tint(CloudwardColors.celadon)
            } else {
                Image(systemName: "folder")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(CloudwardColors.inkBlue)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button("重新读取") {
                onRetry()
            }
            .controlSize(.small)
            .buttonStyle(.bordered)
        }
        .padding(28)
        .frame(maxWidth: .infinity, minHeight: 180)
    }
}

struct SkeletonFileRow: View {
    var depth = 0
    @State private var phase = false

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 4)
                .fill(CloudwardColors.separator.opacity(0.75))
                .frame(width: 18, height: 18)
            RoundedRectangle(cornerRadius: 5)
                .fill(CloudwardColors.separator.opacity(0.7))
                .frame(width: 28, height: 18)
            RoundedRectangle(cornerRadius: 5)
                .fill(CloudwardColors.separator.opacity(0.75))
                .frame(maxWidth: .infinity)
                .frame(height: 12)
            RoundedRectangle(cornerRadius: 5)
                .fill(CloudwardColors.separator.opacity(0.65))
                .frame(width: 84, height: 12)
            RoundedRectangle(cornerRadius: 7)
                .fill(CloudwardColors.separator.opacity(0.65))
                .frame(width: 82, height: 20)
        }
        .padding(.leading, CGFloat(depth) * 18 + 14)
        .padding(.trailing, 14)
        .frame(height: 32)
        .opacity(phase ? 0.42 : 0.9)
        .animation(phase ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true) : nil, value: phase)
        .onAppear {
            phase = true
        }
        .onDisappear {
            phase = false
        }
    }
}

private struct FileListHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            Text("名称")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("本地大小")
                .frame(width: 104, alignment: .trailing)
            Text("iCloud 状态")
                .frame(width: 110, alignment: .leading)
            Text("占用")
                .frame(width: 36, alignment: .center)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
    }
}
