import AppKit
import SwiftUI

struct SyncStatusView: View {
    var state: CloudwardAppState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                TrafficDots()
                Text("同步状态")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Text("最近活动 · \(state.syncActivityUpdatedText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            StatusSection(title: transferSectionTitle, trailing: transferSectionTrailing) {
                if state.syncActivities.isEmpty {
                    EmptyStatusRow(
                        symbolName: "icloud",
                        title: "当前没有活跃传输",
                        detail: state.spotlightStatusMessage ?? "iCloud 元数据监听已启动，会在上传或下载时自动更新。"
                    )
                } else {
                    ForEach(state.syncActivities.prefix(5)) { item in
                        TransferRow(item: item)
                    }
                }
            }

            StatusSection(title: conflictSectionTitle, trailing: nil) {
                if state.visibleSyncConflicts.isEmpty {
                    EmptyStatusRow(
                        symbolName: "checkmark.circle.fill",
                        title: "暂无冲突文件",
                        detail: "检测到冲突版本时会在这里列出。"
                    )
                } else {
                    ForEach(state.visibleSyncConflicts.prefix(4)) { item in
                        ConflictRow(item: item)
                    }
                }
            }

            StatusSection(title: "健康自检", trailing: nil) {
                ForEach(state.syncHealthChecks) { check in
                    HealthRow(check: check)
                }
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: 640, maxHeight: .infinity, alignment: .topLeading)
        .background(CloudwardColors.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(CloudwardColors.separator))
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(CloudwardColors.moonWhite)
    }

    private var transferSectionTitle: String {
        if state.syncActivities.isEmpty {
            return "传输活动 · 静默"
        }

        return "正在同步 · \(state.syncActivities.count) 项"
    }

    private var transferSectionTrailing: String? {
        guard state.syncActivities.isEmpty == false else {
            return state.spotlightStatusMessage
        }

        let bytes = state.syncActivities.reduce(Int64(0)) { $0 + $1.size }
        return bytes > 0 ? "共 \(bytes.cloudwardBytes)" : nil
    }

    private var conflictSectionTitle: String {
        let count = state.visibleSyncConflicts.count
        return count == 0 ? "冲突 · 暂无" : "冲突 · \(count) 项需处理"
    }
}

private struct TrafficDots: View {
    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(Color(red: 1, green: 0.35, blue: 0.32))
            Circle().fill(Color(red: 1, green: 0.72, blue: 0.18))
            Circle().fill(Color(red: 0.18, green: 0.75, blue: 0.27))
        }
        .frame(width: 50, height: 12)
    }
}

private struct StatusSection<Content: View>: View {
    let title: String
    let trailing: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let trailing {
                    Text(trailing)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 0) {
                content
            }
            .background(CloudwardColors.card, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(CloudwardColors.separator.opacity(0.72)))
        }
    }
}

private struct TransferRow: View {
    let item: SyncActivityItem

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Label(item.name, systemImage: item.direction.symbolName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CloudwardColors.inkBlue)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Text(item.detailText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack {
                ProgressView(value: item.progress)
                    .tint(CloudwardColors.celadon)
                Text(item.progressText)
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(CloudwardColors.celadon)
                    .frame(width: 42, alignment: .trailing)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(CloudwardColors.separator.opacity(0.65)).frame(height: 0.5)
        }
    }
}

private struct ConflictRow: View {
    let item: SyncConflictItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(item.name, systemImage: "circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CloudwardColors.inkBlue)
                Text("两端版本不一致")
                    .font(.caption)
                    .foregroundStyle(CloudwardColors.amber)
            }

            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("本地路径      \(item.url.deletingLastPathComponent().lastPathComponent)")
                    Text("记录时间      \(item.updatedAt.cloudwardDateTime) · \(item.size.cloudwardBytes)")
                }
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                Spacer()
                Button("在访达中显示") {
                    NSWorkspace.shared.activateFileViewerSelecting([item.url])
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(14)
        .overlay(alignment: .bottom) {
            Rectangle().fill(CloudwardColors.separator.opacity(0.65)).frame(height: 0.5)
        }
    }
}

private struct HealthRow: View {
    let check: SyncHealthCheck

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: check.state.symbolName)
                .foregroundStyle(tint)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(check.title)
                    .font(.system(size: 13))
                if let detail = check.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(minHeight: 32)
        .overlay(alignment: .bottom) {
            Rectangle().fill(CloudwardColors.separator.opacity(0.65)).frame(height: 0.5)
        }
    }

    private var tint: Color {
        switch check.state {
        case .ok:
            CloudwardColors.celadon
        case .checking:
            CloudwardColors.cloudGray
        case .warning:
            CloudwardColors.amber
        }
    }
}

private struct EmptyStatusRow: View {
    let symbolName: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbolName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CloudwardColors.inkBlue)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle().fill(CloudwardColors.separator.opacity(0.65)).frame(height: 0.5)
        }
    }
}
