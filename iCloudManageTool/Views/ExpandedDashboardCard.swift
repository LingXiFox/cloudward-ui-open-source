import CloudwardCore
import SwiftUI

struct ExpandedDashboardCard: View {
    var state: CloudwardAppState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("全部容器本地占用")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        ByteValueText(bytes: state.spaceAnalysisLocalBytes)
                        Text("共 \(state.spaceAnalysisContainerCount) 个容器")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text("矩形面积 = 目录本地占用 · 点击下钻")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    state.startIndexScan()
                } label: {
                    Image(systemName: state.indexScanPhase.isScanning ? "hourglass" : "arrow.clockwise")
                        .frame(width: 30, height: 30)
                        .background(CloudwardColors.panel, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(state.indexScanPhase.isScanning)

            }

            HStack(alignment: .top, spacing: 16) {
                TreemapPreview(directories: state.topDirectoryStats) { directory in
                    state.revealDirectoryInTree(directory)
                }
                    .frame(minHeight: 390)

                VStack(spacing: 12) {
                    ContainerUsageCard(stats: state.indexContainerStats)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(state.indexCategoryStats) { stat in
                            CategorySummaryCard(stat: stat) {
                                state.presentReleasePreview(
                                    for: state.fileIndex?.localFiles.filter { $0.category == stat.category } ?? [],
                                    title: stat.category.title
                                )
                            }
                        }
                    }
                }
                .frame(width: 408)
            }
        }
        .padding(16)
        .background(CloudwardColors.card, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 12, y: 5)
    }
}

private struct TreemapPreview: View {
    let directories: [IndexedDirectoryStat]
    let onSelectDirectory: (IndexedDirectoryStat) -> Void

    private var displayNodes: [IndexedDirectoryStat] {
        directories
    }

    var body: some View {
        GeometryReader { proxy in
            let slices = TreemapLayout.makeSlices(
                for: displayNodes,
                in: CGRect(origin: .zero, size: proxy.size)
            )
            let colors = [
                CloudwardColors.celadon.opacity(0.28),
                Color.blue.opacity(0.15),
                CloudwardColors.amber.opacity(0.15),
                CloudwardColors.vermilionMist.opacity(0.12),
                CloudwardColors.cloudGray.opacity(0.16)
            ]

            if slices.isEmpty {
                PlaceholderPage(symbolName: "square.grid.3x3", title: "等待索引", message: "Spotlight 快照索引完成后会显示目录面积图。")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ZStack(alignment: .topLeading) {
                    ForEach(Array(slices.enumerated()), id: \.element.id) { index, slice in
                        TreemapBlock(
                            directory: slice.directory,
                            color: colors[index % colors.count]
                        ) {
                            onSelectDirectory(slice.directory)
                        }
                        .frame(width: slice.rect.width, height: slice.rect.height)
                        .position(x: slice.rect.midX, y: slice.rect.midY)
                    }
                }
            }
        }
    }
}

private struct TreemapBlock: View {
    let directory: IndexedDirectoryStat
    let color: Color
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            GeometryReader { proxy in
                VStack(alignment: .leading, spacing: 2) {
                    Text(directory.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(CloudwardColors.inkBlue)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text(directory.bytes.cloudwardBytes)
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(.secondary)

                    if proxy.size.height > 58 {
                        Spacer()
                        Text("\(directory.count) 项 · \(directory.containerName)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .background(color, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.28)))
        .shadow(color: .black.opacity(isHovered ? 0.08 : 0), radius: 8, y: 3)
        .onHover { isHovered = $0 }
        .help("定位到 \(directory.name)")
    }
}

private struct TreemapSlice: Identifiable {
    let directory: IndexedDirectoryStat
    let rect: CGRect

    var id: String { directory.id }
}

private enum TreemapLayout {
    static func makeSlices(for directories: [IndexedDirectoryStat], in rect: CGRect) -> [TreemapSlice] {
        let items = directories
            .filter { $0.bytes > 0 }
            .sorted { $0.bytes > $1.bytes }

        guard items.isEmpty == false, rect.width > 0, rect.height > 0 else {
            return []
        }

        return slice(items: items, rect: rect, depth: 0)
    }

    private static func slice(items: [IndexedDirectoryStat], rect: CGRect, depth: Int) -> [TreemapSlice] {
        if items.count == 1 {
            return [TreemapSlice(directory: items[0], rect: rect.insetBy(dx: 3, dy: 3))]
        }

        let total = max(items.reduce(Int64(0)) { $0 + $1.bytes }, 1)
        let splitTarget = Double(total) / 2
        var leading: [IndexedDirectoryStat] = []
        var leadingBytes: Int64 = 0
        var trailing: [IndexedDirectoryStat] = []

        for item in items {
            if leading.isEmpty || Double(leadingBytes) < splitTarget {
                leading.append(item)
                leadingBytes += item.bytes
            } else {
                trailing.append(item)
            }
        }

        if trailing.isEmpty, let last = leading.popLast() {
            trailing = [last]
            leadingBytes -= last.bytes
        }

        guard leading.isEmpty == false, trailing.isEmpty == false else {
            return items.map { TreemapSlice(directory: $0, rect: rect.insetBy(dx: 3, dy: 3)) }
        }

        let fraction = CGFloat(Double(max(leadingBytes, 1)) / Double(total))
        if rect.width >= rect.height {
            let leadingWidth = rect.width * fraction
            let leadingRect = CGRect(x: rect.minX, y: rect.minY, width: leadingWidth, height: rect.height)
            let trailingRect = CGRect(x: leadingRect.maxX, y: rect.minY, width: rect.width - leadingWidth, height: rect.height)
            return slice(items: leading, rect: leadingRect, depth: depth + 1)
                + slice(items: trailing, rect: trailingRect, depth: depth + 1)
        } else {
            let leadingHeight = rect.height * fraction
            let leadingRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: leadingHeight)
            let trailingRect = CGRect(x: rect.minX, y: leadingRect.maxY, width: rect.width, height: rect.height - leadingHeight)
            return slice(items: leading, rect: leadingRect, depth: depth + 1)
                + slice(items: trailing, rect: trailingRect, depth: depth + 1)
        }
    }
}

private struct CategorySummaryCard: View {
    let stat: IndexedCategoryStat
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(stat.category.title, systemImage: "square.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(stat.category.color)
                Spacer()
                Text("\(Int(stat.fraction * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(stat.bytes.cloudwardBytes)
                .font(.system(size: 22, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(CloudwardColors.inkBlue)

            Button {
                action()
            } label: {
                Label("归云该类", systemImage: "icloud.fill")
                    .frame(maxWidth: .infinity)
                    .frame(height: 26)
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(CloudwardColors.celadon)
            .background(CloudwardColors.celadon.opacity(0.10), in: RoundedRectangle(cornerRadius: 7))
            .disabled(stat.bytes <= 0)
            .opacity(stat.bytes <= 0 ? 0.45 : 1)
            .help(stat.bytes <= 0 ? "该类型无本地占用" : "归云该类")
        }
        .padding(12)
        .frame(height: 112)
        .background(CloudwardColors.panel, in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct ContainerUsageCard: View {
    let stats: [IndexedContainerStat]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("按容器")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CloudwardColors.inkBlue)
                Spacer()
                Text("\(stats.count) 个容器")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { proxy in
                HStack(spacing: 3) {
                    ForEach(stats.prefix(6)) { stat in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(CloudwardColors.celadon.opacity(0.28 + min(stat.fraction, 0.5)))
                            .frame(width: max(proxy.size.width * stat.fraction, 8))
                    }
                }
            }
            .frame(height: 12)
            .clipShape(Capsule())

            ForEach(stats.prefix(3)) { stat in
                HStack {
                    Text(stat.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Text(stat.bytes.cloudwardBytes)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(CloudwardColors.inkBlue)
                }
            }
        }
        .padding(12)
        .frame(minHeight: 112)
        .background(CloudwardColors.panel, in: RoundedRectangle(cornerRadius: 10))
    }
}
