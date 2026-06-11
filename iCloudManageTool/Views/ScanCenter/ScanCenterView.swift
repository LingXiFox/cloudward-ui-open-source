import AppKit
import CloudwardCore
import QuickLookThumbnailing
import SwiftUI

struct ScanCenterView: View {
    @Bindable var state: CloudwardAppState
    let selection: SidebarSelection

    var body: some View {
        VStack(spacing: 0) {
            ScanCenterHeader(state: state, title: title, subtitle: subtitle)

            Divider()

            Group {
                switch selection {
                case .largeFiles:
                    LargeFilesScanPage(state: state)
                case .staleFiles:
                    StaleFilesScanPage(state: state)
                case .redundantFiles:
                    RedundantFilesScanPage(state: state)
                default:
                    EmptyView()
                }
            }
        }
        .background(CloudwardColors.moonWhite)
        .onAppear {
            state.startIndexScanIfNeeded()
        }
    }

    private var title: String {
        switch selection {
        case .largeFiles:
            "大文件"
        case .staleFiles:
            "沉睡文件"
        case .redundantFiles:
            "可疑冗余"
        default:
            "扫描中心"
        }
    }

    private var subtitle: String {
        switch selection {
        case .largeFiles:
            "按本地占用降序找出最值得归云的文件。"
        case .staleFiles:
            "按最后使用时间和可释放空间排序。"
        case .redundantFiles:
            "基于命名和结构启发式识别临时、冲突和开发产物。"
        default:
            "共用同一份 Spotlight 快照索引。"
        }
    }
}

private struct ScanCenterHeader: View {
    @Bindable var state: CloudwardAppState
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(CloudwardColors.inkBlue)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(state.indexStatusText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                if state.indexScanPhase.isScanning {
                    Button {
                        state.cancelIndexScan()
                    } label: {
                        Label("取消", systemImage: "xmark.circle")
                    }
                    .controlSize(.small)
                } else {
                    Button {
                        state.startIndexScan()
                    } label: {
                        Label("重新扫描", systemImage: "arrow.clockwise")
                    }
                    .controlSize(.small)
                }
            }

            if state.indexScanPhase.isScanning {
                ProgressView()
                    .controlSize(.small)
                    .tint(CloudwardColors.celadon)

                if let currentPath = state.indexCurrentPath {
                    Text(currentPath)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .padding(16)
        .background(CloudwardColors.card)
    }
}

private struct LargeFilesScanPage: View {
    @Bindable var state: CloudwardAppState

    var body: some View {
        ScanListShell(
            isEmpty: false,
            emptyTitle: "还没有符合阈值的大文件",
            emptyDetail: "降低阈值或重新扫描后再看。"
        ) {
            VStack(spacing: 12) {
                ScanMetricBand(
                    title: "本地 Top 100 大文件共占",
                    value: state.largeFiles.reduce(0) { $0 + $1.localAllocatedBytes }.cloudwardBytes,
                    detail: "全部释放可省同等本地缓存空间"
                ) {
                    VStack(alignment: .trailing, spacing: 8) {
                        Picker("阈值", selection: $state.largeFileThreshold) {
                            ForEach(LargeFileThreshold.allCases) { threshold in
                                Text(threshold.title).tag(threshold)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 330)

                        HStack(spacing: 8) {
                            if state.largeFileThreshold == .custom {
                                Stepper(value: $state.customLargeFileThresholdMB, in: 1...102_400, step: 50) {
                                    Text("\(state.customLargeFileThresholdMB) MB")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                        .frame(width: 82, alignment: .trailing)
                                }
                                .controlSize(.small)
                            }

                            if state.selectedIndexedFiles.isEmpty == false {
                                Button {
                                    state.presentReleasePreviewForScanSelection(title: "大文件")
                                } label: {
                                    Label("释放所选", systemImage: "checkmark.circle")
                                }
                            }
                        }
                    }
                }

                if state.largeFiles.isEmpty {
                    PlaceholderPage(symbolName: "magnifyingglass", title: "还没有符合阈值的大文件", message: "降低阈值或重新扫描后再看。")
                        .frame(maxWidth: .infinity, minHeight: 260)
                } else {
                    ForEach(state.largeFiles) { file in
                        IndexedFileRow(state: state, file: file, badge: file.category.title) {
                            state.presentReleasePreview(for: [file], title: file.name)
                        }
                    }
                }

                if state.largeFiles.isEmpty == false {
                    Button {
                        state.presentReleasePreview(for: state.largeFiles, title: "大文件")
                    } label: {
                        Label("释放当前列表", systemImage: "icloud.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(CloudwardColors.celadon)
                    .padding(.top, 4)
                }
            }
        }
    }
}

private struct StaleFilesScanPage: View {
    @Bindable var state: CloudwardAppState

    var body: some View {
        let files = state.staleFiles
        ScanListShell(
            isEmpty: false,
            emptyTitle: "暂未发现沉睡文件",
            emptyDetail: "如果 Spotlight 没有最后使用时间，会自动回退到访问时间或修改时间。"
        ) {
            VStack(spacing: 12) {
                ScanMetricBand(
                    title: "这些文件你已经 \(state.staleFileAge.rawValue) 天没碰过了",
                    value: files.reduce(0) { $0 + $1.localAllocatedBytes }.cloudwardBytes,
                    detail: "时间口径会在每行标注"
                ) {
                    HStack(spacing: 8) {
                        Picker("时间", selection: $state.staleFileAge) {
                            ForEach(StaleFileAge.allCases) { age in
                                Text(age.title).tag(age)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 280)

                        if state.selectedIndexedFiles.isEmpty == false {
                            Button {
                                state.presentReleasePreviewForScanSelection(title: "沉睡文件")
                            } label: {
                                Label("释放所选", systemImage: "checkmark.circle")
                            }
                        }
                    }
                }

                if files.isEmpty {
                    PlaceholderPage(symbolName: "moon", title: "暂未发现沉睡文件", message: "如果 Spotlight 没有最后使用时间，会自动回退到访问时间或修改时间。")
                        .frame(maxWidth: .infinity, minHeight: 260)
                } else {
                    ForEach(files) { file in
                        IndexedFileRow(state: state, file: file, badge: file.lastUsed.source.title) {
                            state.presentReleasePreview(for: [file], title: file.name)
                        }
                    }
                }

                if files.isEmpty == false {
                    Button {
                        state.presentReleasePreview(for: files, title: "沉睡文件")
                    } label: {
                        Label("释放当前列表", systemImage: "icloud.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(CloudwardColors.celadon)
                    .padding(.top, 4)
                }
            }
        }
    }
}

private struct RedundantFilesScanPage: View {
    @Bindable var state: CloudwardAppState

    var body: some View {
        ScanListShell(
            isEmpty: false,
            emptyTitle: "暂未发现可疑冗余",
            emptyDetail: "规则只做提示，默认动作仍是归云或在访达中显示。"
        ) {
            VStack(spacing: 12) {
                ScanMetricBand(
                    title: "可疑冗余候选",
                    value: "\(state.redundantFiles.count) 项",
                    detail: "命中规则均可展开查看说明"
                ) {
                    Button {
                        if state.selectedIndexedFiles.isEmpty {
                            state.presentReleasePreview(for: state.redundantFiles, title: "可疑冗余")
                        } else {
                            state.presentReleasePreviewForScanSelection(title: "可疑冗余")
                        }
                    } label: {
                        Label(state.selectedIndexedFiles.isEmpty ? "归云候选" : "释放所选", systemImage: "icloud.and.arrow.up")
                    }
                    .disabled(state.redundantFiles.isEmpty)
                }

                if state.redundantFiles.isEmpty {
                    PlaceholderPage(symbolName: "sparkle.magnifyingglass", title: "暂未发现可疑冗余", message: "规则只做提示，默认动作仍是归云或在访达中显示。")
                        .frame(maxWidth: .infinity, minHeight: 260)
                } else {
                    ForEach(state.redundantFiles) { file in
                        RedundantFileRow(state: state, file: file) {
                            state.presentReleasePreview(for: [file], title: file.name)
                        }
                    }
                }
            }
        }
    }
}

private struct ScanListShell<Content: View>: View {
    let isEmpty: Bool
    let emptyTitle: String
    let emptyDetail: String
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if isEmpty {
                    PlaceholderPage(symbolName: "magnifyingglass", title: emptyTitle, message: emptyDetail)
                        .frame(maxWidth: .infinity, minHeight: 360)
                } else {
                    content
                }
            }
            .padding(16)
        }
    }
}

private struct ScanMetricBand<Trailing: View>: View {
    let title: String
    let value: String
    let detail: String
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 26, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(CloudwardColors.inkBlue)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(CloudwardColors.celadon)
            }

            Spacer()
            trailing
        }
        .padding(16)
        .background(CloudwardColors.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(CloudwardColors.separator.opacity(0.65)))
    }
}

private struct IndexedFileRow: View {
    @Bindable var state: CloudwardAppState
    let file: IndexedFile
    let badge: String
    let releaseAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button {
                state.toggleScanSelection(for: file)
            } label: {
                Image(systemName: state.scanSelection.contains(file.id) ? "checkmark.square.fill" : "square")
                    .foregroundStyle(state.scanSelection.contains(file.id) ? CloudwardColors.celadon : CloudwardColors.cloudGray)
            }
            .buttonStyle(.plain)
            .frame(width: 20)

            FileThumbnail(url: file.url, category: file.category)

            VStack(alignment: .leading, spacing: 5) {
                Text(file.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CloudwardColors.inkBlue)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(breadcrumb)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Text(file.localAllocatedBytes.cloudwardBytes)
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundStyle(CloudwardColors.inkBlue)
                .frame(width: 96, alignment: .trailing)

            Text(badge)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(file.category.color)
                .padding(.horizontal, 8)
                .frame(height: 22)
                .background(file.category.color.opacity(0.12), in: Capsule())

            Button {
                state.detectLock(for: file)
            } label: {
                scanLockIndicator
            }
            .buttonStyle(.borderless)
            .help(lockHelp)

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([file.url])
            } label: {
                Image(systemName: "finder")
            }
            .buttonStyle(.borderless)

            Button(action: releaseAction) {
                Image(systemName: "icloud.and.arrow.up")
            }
            .buttonStyle(.borderless)
            .disabled(file.cloudStatus != .localCopy)
        }
        .padding(.horizontal, 14)
        .frame(height: 58)
        .background(CloudwardColors.card, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(CloudwardColors.separator.opacity(0.55)))
    }

    private var breadcrumb: String {
        let parentName = file.url.deletingLastPathComponent().lastPathComponent
        guard parentName.isEmpty == false, parentName != "Documents", parentName != file.containerName else {
            return file.containerName
        }

        return "\(file.containerName) / \(parentName)"
    }

    private var lockState: NodeLockState {
        state.lockState(for: file)
    }

    @ViewBuilder
    private var scanLockIndicator: some View {
        if lockState.isChecking {
            Image(systemName: "clock")
                .foregroundStyle(CloudwardColors.cloudGray)
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

    private var lockHelp: String {
        if lockState.hasHoldingProcesses {
            return "被 \(lockState.processes.count) 个 App 占用"
        }

        return lockState.statusText
    }
}

private struct RedundantFileRow: View {
    @Bindable var state: CloudwardAppState
    let file: IndexedFile
    let releaseAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            IndexedFileRow(state: state, file: file, badge: "\(Int((file.redundancyMatches.map(\.confidence).max() ?? 0) * 100))%") {
                releaseAction()
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(file.redundancyMatches) { match in
                        Label(match.message, systemImage: "sparkle.magnifyingglass")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                Button {
                    confirmMoveToTrash(file)
                } label: {
                    Label("移到废纸篓", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
        }
        .background(CloudwardColors.card.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
    }

    private func confirmMoveToTrash(_ file: IndexedFile) {
        let alert = NSAlert()
        alert.messageText = "将 \(file.name) 移到废纸篓？"
        alert.informativeText = "这会同时从 iCloud Drive 中移除该项目。需要时可从废纸篓恢复。归云更安全，不会删除云端文件。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "移到废纸篓")
        alert.addButton(withTitle: "取消")

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        NSWorkspace.shared.recycle([file.url]) { _, error in
            if error != nil {
                NSSound.beep()
            }
        }
    }
}

private struct FileThumbnail: View {
    let url: URL
    let category: IndexedFileCategory
    @State private var thumbnail: NSImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(category.color.opacity(0.13))
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 42, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: symbolName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(category.color)
            }
        }
        .frame(width: 42, height: 42)
        .task(id: url) {
            await loadThumbnail()
        }
    }

    private var symbolName: String {
        switch category {
        case .video:
            "film"
        case .image:
            "photo"
        case .audio:
            "waveform"
        case .document:
            "doc.text"
        case .archive:
            "archivebox"
        case .design:
            "paintpalette"
        case .code:
            "curlybraces"
        case .other:
            url.hasDirectoryPath ? "folder" : "doc"
        }
    }

    private func loadThumbnail() async {
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: 84, height: 84),
            scale: NSScreen.main?.backingScaleFactor ?? 2,
            representationTypes: .thumbnail
        )

        do {
            let representation = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            thumbnail = representation.nsImage
        } catch {
            thumbnail = nil
        }
    }
}
