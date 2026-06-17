import SwiftData
import SwiftUI

struct HistoryView: View {
    @Query(sort: \ReleaseHistoryRecord.createdAt, order: .reverse) private var records: [ReleaseHistoryRecord]

    private var totalBytes: Int64 {
        records.reduce(0) { $0 + $1.releasedBytes }
    }

    private var totalFiles: Int {
        records.reduce(0) { $0 + $1.fileCount }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HistorySummaryCard(totalBytes: totalBytes, totalFiles: totalFiles, records: records)

                if records.isEmpty {
                    PlaceholderPage(
                        symbolName: "clock.arrow.circlepath",
                        title: "还没有归云历史",
                        message: "完成一次释放后,这里会记录时间、来源、文件数和释放空间。"
                    )
                    .frame(maxWidth: .infinity, minHeight: 360)
                } else {
                    VStack(spacing: 0) {
                        ForEach(records) { record in
                            HistoryRow(record: record)
                        }
                    }
                    .background(CloudwardColors.card, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(CloudwardColors.separator.opacity(0.72)))
                }
            }
            .padding(16)
        }
        .background(CloudwardColors.moonWhite)
    }
}

private struct HistorySummaryCard: View {
    let totalBytes: Int64
    let totalFiles: Int
    let records: [ReleaseHistoryRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("已累计归云")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ByteValueText(bytes: totalBytes, numberSize: 38)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(records.count) 次记录")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(totalFiles) 个文件")
                        .font(.system(size: 14, weight: .semibold).monospacedDigit())
                        .foregroundStyle(CloudwardColors.inkBlue)
                }
            }

            MonthlyHistoryChart(records: records)
                .frame(height: 86)
        }
        .padding(16)
        .background(CloudwardColors.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(CloudwardColors.separator.opacity(0.7)))
    }
}

private struct MonthlyHistoryChart: View {
    let records: [ReleaseHistoryRecord]

    private var buckets: [MonthBucket] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: records) { record in
            let components = calendar.dateComponents([.year, .month], from: record.createdAt)
            return calendar.date(from: components) ?? record.createdAt
        }

        let source = grouped.map { month, items in
            MonthBucket(
                month: month,
                bytes: items.reduce(0) { $0 + $1.releasedBytes }
            )
        }
        .sorted { $0.month < $1.month }

        return Array(source.suffix(6))
    }

    var body: some View {
        let maxBytes = max(buckets.map(\.bytes).max() ?? 1, 1)

        HStack(alignment: .bottom, spacing: 8) {
            if buckets.isEmpty {
                RoundedRectangle(cornerRadius: 8)
                    .fill(CloudwardColors.panel)
                    .overlay {
                        Text("按月统计会在这里出现")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
            } else {
                ForEach(buckets) { bucket in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(CloudwardColors.celadon.opacity(0.35))
                            .frame(height: max(CGFloat(bucket.bytes) / CGFloat(maxBytes) * 54, 8))
                        Text(bucket.month.cloudwardMonth)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

private struct MonthBucket: Identifiable {
    let month: Date
    let bytes: Int64

    var id: Date { month }
}

private struct HistoryRow: View {
    let record: ReleaseHistoryRecord

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "icloud.fill")
                .foregroundStyle(CloudwardColors.celadon)
                .frame(width: 28, height: 28)
                .background(CloudwardColors.celadon.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(record.scopeTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CloudwardColors.inkBlue)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("\(record.source.title) · \(record.createdAt.cloudwardDateTime)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(record.releasedBytes.cloudwardBytes)
                    .font(.system(size: 14, weight: .semibold).monospacedDigit())
                    .foregroundStyle(CloudwardColors.celadon)
                Text("\(record.selectedCount) 选择 · \(record.fileCount) 驱逐 · \(record.skipped) 跳过 · \(record.failed) 失败")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 60)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(CloudwardColors.separator.opacity(0.65))
                .frame(height: 0.5)
        }
    }
}
