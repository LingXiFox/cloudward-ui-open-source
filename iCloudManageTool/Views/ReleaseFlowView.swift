import CloudwardCore
import SwiftUI

struct ReleaseFlowView: View {
    @Bindable var state: CloudwardAppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 22) {
            ReleaseProgressPanel(state: state, dismiss: dismiss)
            ReleaseSummaryPanel(state: state, dismiss: dismiss)
        }
        .padding(22)
        .background(CloudwardColors.moonWhite)
        .animation(reduceMotion ? .default : Motion.standard, value: state.releasePhase)
    }
}

private struct ReleaseProgressPanel: View {
    @Bindable var state: CloudwardAppState
    let dismiss: DismissAction
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(24)

            Spacer()

            progressRing
                .frame(width: 210, height: 210)
                .frame(maxWidth: .infinity)

            releaseLog
                .padding(.top, 28)

            currentFileLine
                .padding(.top, 14)

            Spacer()

            Text("文件保留在 iCloud,本地仅移除缓存副本 · 可随时重新下载")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CloudwardColors.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(CloudwardColors.separator))
        .animation(reduceMotion ? .default : Motion.standard, value: state.releasePhase)
        .animation(reduceMotion ? .default : .linear(duration: 0.1), value: state.releaseFreedBytes)
        .animation(reduceMotion ? .default : .linear(duration: 0.1), value: state.releaseProcessedEvents)
    }

    private var header: some View {
        HStack {
            Text(headerTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(CloudwardColors.inkBlue)
            Text("· \(state.releaseScopeTitle)")
                .foregroundStyle(.secondary)
            Spacer()

            if state.releasePhase == .preparing || state.releasePhase == .running {
                Button("取消") {
                    state.cancelRelease()
                }
                .buttonStyle(.bordered)
                .foregroundStyle(CloudwardColors.vermilionMist)
            } else {
                Button("关闭") {
                    state.dismissReleaseFlow()
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var headerTitle: String {
        switch state.releasePhase {
        case .ready:
            "准备归云"
        case .preparing:
            "正在准备"
        case .running:
            "正在归云"
        case .finished:
            "已完成"
        case .cancelled:
            "已停止"
        }
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(CloudwardColors.separator, lineWidth: 14)
            Circle()
                .trim(from: 0, to: state.releaseProgressFraction)
                .stroke(
                    LinearGradient(colors: [CloudwardColors.celadon.opacity(0.6), CloudwardColors.celadon], startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? .default : .linear(duration: 0.1), value: state.releaseProgressFraction)

            VStack(spacing: 6) {
                Text(ringCaption)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ByteValueText(bytes: ringBytes, numberSize: 40)
                Text(ringDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var ringCaption: String {
        switch state.releasePhase {
        case .ready:
            "预计释放"
        case .preparing:
            "准备中"
        case .running:
            "已释放"
        case .finished:
            "本次释放"
        case .cancelled:
            "已释放"
        }
    }

    private var ringBytes: Int64 {
        switch state.releasePhase {
        case .ready:
            state.releaseEstimatedBytes
        case .preparing:
            state.releaseEstimatedBytes
        case .running, .finished, .cancelled:
            state.releaseFreedBytes
        }
    }

    private var ringDetail: String {
        switch state.releasePhase {
        case .ready:
            "\(state.releaseTargetURLs.count) 个入口 · \(state.releasePreviewCount) 个文件"
        case .preparing:
            "准备中 \(state.releasePreparationProcessed)/\(max(state.releasePreparationTotal, 1))"
        case .running:
            "\(Int(state.releaseProgressFraction * 100))% · \(state.releaseProcessedEvents)/\(max(state.releaseTotal, 1))"
        case .finished:
            "驱逐 \(state.releaseSummary?.total ?? state.releaseTotal) · 跳过 \(state.releaseSummary?.skipped ?? state.releaseSkippedCount)"
        case .cancelled:
            "任务已停止"
        }
    }

    private var releaseLog: some View {
        VStack(spacing: 10) {
            if state.releaseLogLines.isEmpty {
                ReleaseFileLine(
                    symbol: "icloud.and.arrow.up.fill",
                    text: "点击右侧「开始归云」后执行真实 iCloud 本地副本释放",
                    detail: "此操作不会删除云端文件",
                    tint: CloudwardColors.celadon
                )
            } else {
                ForEach(state.releaseLogLines.reversed().prefix(6)) { line in
                    ReleaseFileLine(
                        symbol: line.kind.symbolName,
                        text: line.title,
                        detail: line.detail,
                        tint: line.kind.tint
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .animation(reduceMotion ? .default : Motion.standard, value: state.releaseLogLines.count)
    }

    private var currentFileLine: some View {
        HStack(spacing: 8) {
            Image(systemName: state.releasePhase == .finished ? "checkmark.circle" : "doc")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(state.releasePhase == .finished ? CloudwardColors.celadon : CloudwardColors.cloudGray)
                .frame(width: 16)
            Text("当前文件")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(currentFileText)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(CloudwardColors.inkBlue)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
        .frame(maxWidth: 360, alignment: .leading)
    }

    private var currentFileText: String {
        if state.releasePhase == .finished {
            return "完成"
        }

        return state.releaseCurrentFileName ?? "等待开始"
    }
}

private struct ReleaseFileLine: View {
    let symbol: String
    let text: String
    let detail: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(CloudwardColors.inkBlue)
                .lineLimit(1)
                .truncationMode(.middle)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: 360, alignment: .leading)
    }
}

private struct ReleaseSummaryPanel: View {
    @Bindable var state: CloudwardAppState
    let dismiss: DismissAction

    var body: some View {
        VStack(spacing: 22) {
            Spacer().frame(height: 16)

            Image(systemName: summarySymbol)
                .font(.system(size: 58, weight: .light))
                .foregroundStyle(summaryTint)

            VStack(spacing: 4) {
                Text(summaryTitle)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(CloudwardColors.inkBlue)
                Text(summarySubtitle)
                    .foregroundStyle(.secondary)
            }

            metrics
                .padding(.horizontal, 24)

            detailCard
                .padding(.horizontal, 24)

            Spacer()

            footer
                .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CloudwardColors.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(CloudwardColors.separator))
    }

    private var summarySymbol: String {
        switch state.releasePhase {
        case .ready:
            "icloud.and.arrow.up"
        case .preparing:
            "hourglass"
        case .running:
            "arrow.triangle.2.circlepath.icloud"
        case .finished:
            "checkmark.circle"
        case .cancelled:
            "pause.circle"
        }
    }

    private var summaryTint: Color {
        state.releasePhase == .cancelled ? CloudwardColors.amber : CloudwardColors.celadon
    }

    private var summaryTitle: String {
        switch state.releasePhase {
        case .ready:
            "确认归云"
        case .preparing:
            "正在准备"
        case .running:
            "归云进行中"
        case .finished:
            "已全部归云"
        case .cancelled:
            "任务已停止"
        }
    }

    private var summarySubtitle: String {
        switch state.releasePhase {
        case .ready:
            "将移除本地缓存副本,云端文件仍然保留"
        case .preparing:
            "正在筛选无需处理的云端项"
        case .running:
            "正在按事件流更新释放进度"
        case .finished:
            "本地空间已释放,文件安然存放于 iCloud"
        case .cancelled:
            "已停止派发新任务,可稍后重试"
        }
    }

    private var metrics: some View {
        VStack(spacing: 0) {
            SummaryRow(title: "预计释放空间", value: state.releaseEstimatedBytes.cloudwardBytes, tint: CloudwardColors.celadon)
            SummaryRow(title: "已释放空间", value: state.releaseFreedBytes.cloudwardBytes, tint: CloudwardColors.celadon)
            SummaryRow(title: "选择项目", value: "\(state.releaseSelectedCount) 个")
            SummaryRow(title: "计划驱逐", value: "\(state.releaseTotal) 个")
            SummaryRow(title: "处理结果", value: resultText, tint: state.releaseSummary == nil ? CloudwardColors.inkBlue : CloudwardColors.amber)
        }
        .background(CloudwardColors.card, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(CloudwardColors.separator))
    }

    private var resultText: String {
        guard let summary = state.releaseSummary else {
            if state.releasePhase == .preparing {
                return "准备 \(state.releasePreparationProcessed)/\(max(state.releasePreparationTotal, 1))"
            }

            return "\(state.releaseProcessedEvents)/\(max(state.releaseTotal, 1)) · 跳过 \(state.releaseSkippedCount)"
        }

        return "\(summary.total) 驱逐 · \(summary.skipped) 跳过 · \(summary.failed) 失败"
    }

    private var detailCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(detailHeaderText)
                .font(.caption)
                .foregroundStyle(.secondary)

            if state.releaseIssueDetails.isEmpty {
                HStack {
                    ZStack {
                        Circle().stroke(CloudwardColors.celadon.opacity(0.24), lineWidth: 2)
                        Circle().stroke(CloudwardColors.celadon.opacity(0.16), lineWidth: 10)
                        Image(systemName: detailSymbol)
                            .foregroundStyle(CloudwardColors.cloudGray)
                    }
                    .frame(width: 48, height: 48)

                    Text(detailTitle)
                        .font(.system(size: 13))
                        .foregroundStyle(CloudwardColors.inkBlue)
                        .lineLimit(1)
                    Spacer()
                    Text(detailValue)
                        .foregroundStyle(.secondary.opacity(0.8))
                }
                .padding(10)
                .background(CloudwardColors.card, in: RoundedRectangle(cornerRadius: 8))
            } else {
                VStack(spacing: 0) {
                    ForEach(state.releaseIssueDetails.prefix(4)) { issue in
                        ReleaseIssueRow(issue: issue)
                    }
                    if state.releaseIssueOverflowCount > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(CloudwardColors.amber)
                            Text("另有 \(state.releaseIssueOverflowCount) 项,见诊断日志导出")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(10)
                    }
                }
                .background(CloudwardColors.card, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(14)
        .background(CloudwardColors.panel, in: RoundedRectangle(cornerRadius: 9))
    }

    private var detailHeaderText: String {
        if state.releaseIssueDetails.isEmpty {
            return "签名动效「归云涟漪」已绑定成功事件,文件行会逐个化云"
        }

        return "未归云明细 · 可按原因重试或先处理占用/同步状态"
    }

    private var detailSymbol: String {
        state.releasePhase == .finished ? "icloud" : "doc"
    }

    private var detailTitle: String {
        state.releaseLogLines.last?.title ?? state.releaseTargetURLs.first?.lastPathComponent ?? "等待归云任务"
    }

    private var detailValue: String {
        switch state.releasePhase {
        case .ready:
            "未开始"
        case .preparing:
            "\(state.releasePreparationProcessed)/\(max(state.releasePreparationTotal, 1))"
        case .running:
            "\(Int(state.releaseProgressFraction * 100))%"
        case .finished:
            "已归云"
        case .cancelled:
            "已停止"
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            if state.releasePhase == .ready || state.releasePhase == .cancelled || state.releasePhase == .preparing {
                Button(state.releasePhase == .preparing ? "准备中…" : "开始归云") {
                    state.startRelease()
                }
                .buttonStyle(.borderedProminent)
                .tint(CloudwardColors.celadon)
                .disabled(state.releasePhase == .preparing)
            } else if state.releasePhase == .running {
                Button("取消") {
                    state.cancelRelease()
                }
                .buttonStyle(.bordered)
                .foregroundStyle(CloudwardColors.vermilionMist)
            } else {
                Button("在访达中显示") {
                    if let url = state.releaseTargetURLs.first {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                }
                .buttonStyle(.bordered)
                Button("完成") {
                    state.dismissReleaseFlow()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(CloudwardColors.celadon)
            }
        }
    }
}

private struct ReleaseIssueRow: View {
    let issue: ReleaseIssueDetail

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: issue.kind.symbolName)
                .foregroundStyle(issue.kind.tint)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(issue.url.lastPathComponent)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CloudwardColors.inkBlue)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("\(issue.kind.title) · \(issue.reason)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .frame(height: 44)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(CloudwardColors.separator.opacity(0.65))
                .frame(height: 0.5)
        }
    }
}

private struct SummaryRow: View {
    let title: String
    let value: String
    var tint: Color = CloudwardColors.inkBlue

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold).monospacedDigit())
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(CloudwardColors.separator.opacity(0.65))
                .frame(height: 0.5)
        }
    }
}
