import SwiftUI

/// 卷存储空间容量可视化条形图与占用统计卡片
public struct VolumeCapacityChartView: View {
    public let partition: DiskPartition
    @Environment(\.locale) private var locale

    private var isChinese: Bool {
        locale.identifier.hasPrefix("zh")
    }

    public init(partition: DiskPartition) {
        self.partition = partition
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(L10n.tr("capacity_overview", isChinese: isChinese), systemImage: "chart.pie.fill")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(Int(partition.usagePercentage * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(barColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(barColor.opacity(0.12))
                    .clipShape(Capsule())
            }

            // 大号容量分段进度条 (带圆角和渐变光泽)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.ntfsCapacityFree)
                        .frame(height: 18)

                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [barColor, barColor.opacity(0.85)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: max(0, min(geo.size.width, geo.size.width * CGFloat(partition.usagePercentage))),
                            height: 18
                        )
                }
            }
            .frame(height: 18)

            // 统计信息三栏卡片网格
            HStack(spacing: 12) {
                statCard(
                    title: L10n.tr("capacity_used", isChinese: isChinese),
                    value: partition.formattedUsed,
                    icon: "externaldrive.fill.badge.checkmark",
                    accentColor: barColor
                )

                statCard(
                    title: L10n.tr("capacity_available", isChinese: isChinese),
                    value: partition.formattedFree,
                    icon: "sparkles",
                    accentColor: Color.ntfsGreen
                )

                statCard(
                    title: L10n.tr("capacity_total", isChinese: isChinese),
                    value: partition.formattedTotal,
                    icon: "internaldrive.fill",
                    accentColor: Color.ntfsIndigo
                )
            }
        }
        .ntfsCardStyle(cornerRadius: 12, padding: 16)
    }

    private func statCard(title: String, value: String, icon: String, accentColor: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(accentColor.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.ntfsSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.ntfsBorderColor, lineWidth: 1)
        )
    }

    private var barColor: Color {
        if partition.usagePercentage > 0.90 {
            return Color.ntfsCapacityWarning
        }
        return Color.ntfsCapacityUsed
    }
}
