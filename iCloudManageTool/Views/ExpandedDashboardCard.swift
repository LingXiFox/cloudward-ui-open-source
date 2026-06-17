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

                Text("圆环代表此分类在整体占比")
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
                CategoryPieChart(stats: state.indexCategoryStats, totalBytes: state.spaceAnalysisLocalBytes)

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

private struct CategoryPieChart: View {
    let stats: [IndexedCategoryStat]
    let totalBytes: Int64

    @State private var hoveredCategory: IndexedFileCategory?

    private let innerRadiusFraction: CGFloat = 0.58
    private let hoverOutset: CGFloat = 14

    private var validStats: [IndexedCategoryStat] {
        stats.filter { $0.bytes > 0 }
    }

    private var total: Double {
        Double(max(validStats.reduce(Int64(0)) { $0 + $1.bytes }, 1))
    }

    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { proxy in
                let diameter = min(proxy.size.width, proxy.size.height) * 0.72
                let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
                let radius = diameter / 2
                let innerR = radius * innerRadiusFraction
                let chartSide = diameter + hoverOutset * 2
                let chartCenter = CGPoint(x: chartSide / 2, y: chartSide / 2)

                ZStack {
                    ForEach(Array(validStats.enumerated()), id: \.element.id) { index, stat in
                        let start = startAngle(for: index)
                        let end = endAngle(for: index)
                        let isHovered = hoveredCategory == stat.category
                        let mid = Angle.degrees((start.degrees + end.degrees) / 2)

                        let scale: CGFloat = isHovered ? 1.06 : 1.0
                        let dx: CGFloat = isHovered ? cos(CGFloat(mid.radians)) * 6 : 0
                        let dy: CGFloat = isHovered ? sin(CGFloat(mid.radians)) * 6 : 0

                        PieArc(startAngle: start, endAngle: end, innerRadius: innerR)
                            .fill(stat.category.color)
                            .frame(width: diameter, height: diameter)
                            .scaleEffect(scale)
                            .offset(x: dx, y: dy)
                            .zIndex(isHovered ? 1 : 0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hoveredCategory)

                        if stat.fraction > 0.08 {
                            let labelR = radius * 0.76
                            let x = cos(CGFloat(mid.radians)) * labelR
                            let y = sin(CGFloat(mid.radians)) * labelR
                            Text(String(format: "%.0f%%", stat.fraction * 100))
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
                                .position(x: chartCenter.x + x + dx, y: chartCenter.y + y + dy)
                                .zIndex(isHovered ? 2 : 1)
                                .allowsHitTesting(false)
                        }
                    }

                    Circle()
                        .fill(CloudwardColors.card)
                        .frame(width: diameter * innerRadiusFraction)
                        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                        .allowsHitTesting(false)
                        .zIndex(3)

                    VStack(spacing: 2) {
                        ByteValueText(bytes: totalBytes)
                        Text("\(validStats.count) 个分类")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .allowsHitTesting(false)
                    .zIndex(4)

                    Color.clear
                        .frame(width: chartSide, height: chartSide)
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                hoveredCategory = category(at: location, center: chartCenter, outerRadius: radius + hoverOutset, innerRadius: innerR)
                            case .ended:
                                hoveredCategory = nil
                            }
                        }
                        .zIndex(5)
                }
                .frame(width: chartSide, height: chartSide)
                .position(center)
            }

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 4
            ) {
                ForEach(validStats) { stat in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(stat.category.color)
                            .frame(width: 9, height: 9)
                        Text(stat.category.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(CloudwardColors.inkBlue)
                            .lineLimit(1)
                        Spacer()
                        Text(stat.bytes.cloudwardBytes)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(hoveredCategory == stat.category
                                  ? CloudwardColors.celadon.opacity(0.12)
                                  : Color.clear)
                    )
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hoveredCategory)
                    .onHover { hovering in
                        hoveredCategory = hovering ? stat.category : nil
                    }
                }
            }
        }
        .frame(minHeight: 390)
    }

    private func startAngle(for index: Int) -> Angle {
        let precedingSum = validStats.prefix(index).reduce(0.0) { $0 + Double($1.bytes) }
        let fraction = precedingSum / total
        return Angle.degrees(360 * fraction - 90)
    }

    private func endAngle(for index: Int) -> Angle {
        let includingSum = validStats.prefix(index + 1).reduce(0.0) { $0 + Double($1.bytes) }
        let fraction = includingSum / total
        return Angle.degrees(360 * fraction - 90)
    }

    private func category(at location: CGPoint, center: CGPoint, outerRadius: CGFloat, innerRadius: CGFloat) -> IndexedFileCategory? {
        let dx = location.x - center.x
        let dy = location.y - center.y
        let distance = hypot(dx, dy)

        guard distance >= innerRadius, distance <= outerRadius else {
            return nil
        }

        var progress = (atan2(dy, dx) + .pi / 2) / (2 * .pi)
        if progress < 0 {
            progress += 1
        }

        var accumulated = 0.0
        for stat in validStats {
            accumulated += Double(stat.bytes) / total
            if progress <= accumulated {
                return stat.category
            }
        }

        return validStats.last?.category
    }
}

private struct PieArc: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let innerRadius: CGFloat

    nonisolated func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        var path = Path()

        path.addArc(
            center: center,
            radius: outerRadius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )

        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: endAngle,
            endAngle: startAngle,
            clockwise: true
        )

        path.closeSubpath()
        return path
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
