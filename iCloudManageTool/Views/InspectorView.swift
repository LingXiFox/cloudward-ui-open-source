import AppKit
import CloudwardCore
import SwiftUI

struct InspectorView: View {
    var state: CloudwardAppState

    var body: some View {
        VStack(alignment: .center, spacing: 18) {
            if let node = state.selectedNode {
                NodeInspector(state: state, node: node)
            } else {
                PlaceholderPage(
                    symbolName: "sidebar.right",
                    title: "未选择文件",
                    message: "选择一行查看状态、大小与占用锁。"
                )
            }

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 28)
    }
}

private struct NodeInspector: View {
    var state: CloudwardAppState
    let node: FileNode

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 10) {
                Image(systemName: node.isDirectory ? "folder" : "doc")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(CloudwardColors.cloudGray)

                VStack(spacing: 2) {
                    Text(node.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(CloudwardColors.inkBlue)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    Text(node.isDirectory ? "文件夹" : fileKind)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 6)

            VStack(spacing: 0) {
                InspectorMetric(title: "本地大小", value: node.localAllocatedBytes.cloudwardBytes)
                InspectorMetric(title: "iCloud 状态", value: node.cloudStatus.displayName)
                InspectorMetric(title: "上次修改", value: modificationDateText)
                InspectorMetric(title: "所在位置", value: locationText)
            }
            .background(CloudwardColors.card, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(CloudwardColors.separator.opacity(0.6)))

            lockSection

            HStack(spacing: 8) {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([node.url])
                } label: {
                    Label("访达", systemImage: "finder")
                }

                Button {
                    state.detectLock(for: node)
                } label: {
                    Label("检测占用", systemImage: "lock")
                }
                .disabled(state.lockState(for: node).isChecking)
            }

            Button {
                state.presentReleasePreview(for: node)
            } label: {
                Label("立即释放", systemImage: "icloud.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(CloudwardColors.celadon)
            .disabled(node.localAllocatedBytes <= 0 || node.cloudStatus.isSyncBlocked || node.cloudStatus == .allEvicted || node.cloudStatus == .empty)
        }
    }

    private var fileKind: String {
        if node.url.pathExtension.isEmpty {
            return "文件"
        }

        return "\(node.url.pathExtension.uppercased()) 文件"
    }

    private var modificationDateText: String {
        guard let modificationDate = node.modificationDate else {
            return "未知"
        }

        return modificationDate.cloudwardDateTime
    }

    private var locationText: String {
        let parentURL = node.url.deletingLastPathComponent()
        if let container = state.containers.first(where: { node.url.standardizedFileURL.path.hasPrefix($0.url.standardizedFileURL.path) }) {
            if parentURL.standardizedFileURL.path == container.url.standardizedFileURL.path {
                return container.name
            }

            let relativeComponents = parentURL.standardizedFileURL.pathComponents.dropFirst(container.url.standardizedFileURL.pathComponents.count)
            let suffix = relativeComponents.joined(separator: " / ")
            return suffix.isEmpty ? container.name : "\(container.name) / \(suffix)"
        }

        return parentURL.lastPathComponent
    }

    @ViewBuilder
    private var lockSection: some View {
        let lockState = state.lockState(for: node)

        VStack(alignment: .leading, spacing: 10) {
            if node.cloudStatus.isSyncBlocked {
                Label(syncBlockTitle, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CloudwardColors.amber)

                Text(lockMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            switch lockState.phase {
            case .idle:
                LockInfoRow(
                    symbolName: "ellipsis.circle",
                    title: "尚未检测进程占用",
                    detail: "选择文件后会自动检测，也可手动重扫。",
                    tint: CloudwardColors.cloudGray
                )
            case .checking:
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在检测进程占用")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(CloudwardColors.inkBlue)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(CloudwardColors.card, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(CloudwardColors.separator.opacity(0.6)))
            case .checked where lockState.processes.isEmpty:
                LockInfoRow(
                    symbolName: "checkmark.circle.fill",
                    title: "未发现 App 占用",
                    detail: "若释放失败，可再次检测或在访达确认文件状态。",
                    tint: CloudwardColors.celadon
                )
            case .checked:
                Label("被 \(lockState.processes.count) 个 App 占用,暂不可释放", systemImage: "lock.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CloudwardColors.amber)

                VStack(spacing: 8) {
                    ForEach(lockState.processes) { process in
                        HoldingProcessRow(process: process) {
                            state.detectLock(for: node)
                        }
                    }
                }
                .padding(10)
                .background(CloudwardColors.card, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(CloudwardColors.separator.opacity(0.6)))

                Text("退出占用 App 后,该文件即可重新尝试归云。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case let .unavailable(message):
                LockInfoRow(
                    symbolName: "questionmark.circle",
                    title: "无法检测占用",
                    detail: message,
                    tint: CloudwardColors.amber
                )
            }
        }
    }

    private var syncBlockTitle: String {
        switch node.cloudStatus {
        case .uploading:
            "文件仍在上传"
        case .notUploaded:
            "文件尚未上传"
        case .conflict:
            "文件存在冲突"
        default:
            "同步状态暂不可释放"
        }
    }

    private var lockMessage: String {
        switch node.cloudStatus {
        case .uploading:
            "文件仍在上传，暂不可释放。"
        case .notUploaded:
            "文件尚未上传到 iCloud，释放会被跳过。"
        case .conflict:
            "检测到冲突版本，需要先处理冲突。"
        default:
            "退出占用 App 后,该文件即可归云。"
        }
    }
}

private struct LockInfoRow: View {
    let symbolName: String
    let title: String
    let detail: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbolName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CloudwardColors.card, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(CloudwardColors.separator.opacity(0.6)))
    }
}

private struct InspectorMetric: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(CloudwardColors.inkBlue)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(CloudwardColors.separator.opacity(0.6))
                .frame(height: 0.5)
        }
    }
}

private struct HoldingProcessRow: View {
    let process: HoldingProcess
    let onTerminate: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            processIcon

            VStack(alignment: .leading, spacing: 1) {
                Text(process.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CloudwardColors.inkBlue)
                    .lineLimit(1)
                Text("PID \(process.pid)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("退出该 App") {
                confirmTerminate()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(NSRunningApplication(processIdentifier: process.pid) == nil)
        }
    }

    @ViewBuilder
    private var processIcon: some View {
        if let appBundlePath = process.appBundlePath {
            Image(nsImage: NSWorkspace.shared.icon(forFile: appBundlePath))
                .resizable()
                .frame(width: 28, height: 28)
        } else {
            Text(process.shortIconText)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(CloudwardColors.inkBlue, in: RoundedRectangle(cornerRadius: 6))
        }
    }

    private func confirmTerminate() {
        let alert = NSAlert()
        alert.messageText = "退出 \(process.displayName)？"
        alert.informativeText = "退出后可重新检测占用，再尝试归云该文件。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "退出该 App")
        alert.addButton(withTitle: "取消")

        guard alert.runModal() == .alertFirstButtonReturn,
              let runningApplication = NSRunningApplication(processIdentifier: process.pid) else {
            return
        }

        runningApplication.terminate()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            onTerminate()
        }
    }
}
