import SwiftUI

/// 物理全盘分区结构分布与切片图谱卡片
public struct PartitionMapVisualizerView: View {
    public let partition: DiskPartition
    @Environment(\.locale) private var locale

    private var isChinese: Bool {
        locale.identifier.hasPrefix("zh")
    }

    public init(partition: DiskPartition) {
        self.partition = partition
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(L10n.tr("part_map_title", isChinese: isChinese), systemImage: "square.split.2x1.fill")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(L10n.tr("gpt_partition_table", isChinese: isChinese))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.ntfsBadgeBackground)
                    .clipShape(Capsule())
            }

            // 分区结构条 (采用高质感微光泽切片)
            GeometryReader { geo in
                HStack(spacing: 3) {
                    // EFI 系统保留切片
                    ZStack {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.ntfsPartitionEFI, Color.ntfsPartitionEFI.opacity(0.85)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        Text("EFI")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(width: max(28, geo.size.width * 0.06))

                    // 主数据分区切片 (当前选定)
                    ZStack {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.ntfsPartitionNTFS, Color.ntfsPartitionNTFS.opacity(0.9)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.white)
                            Text(partition.label)
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Text("(\(partition.formattedTotal))")
                                .font(.system(size: 9.5))
                                .foregroundColor(.white.opacity(0.85))
                        }
                        .padding(.horizontal, 6)
                    }
                    .frame(width: max(120, geo.size.width * 0.86))
                    .overlay(
                        Rectangle()
                            .stroke(Color.white.opacity(0.4), lineWidth: 1)
                    )

                    // 保留切片
                    Rectangle()
                        .fill(Color.ntfsCapacityFree)
                        .frame(maxWidth: .infinity)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.ntfsBorderColor, lineWidth: 1)
                )
            }
            .frame(height: 28)

            // 图例说明
            HStack(spacing: 16) {
                legendItem(title: "\(L10n.tr("part_type_efi", isChinese: isChinese)) (200 MB)", color: Color.ntfsPartitionEFI)
                legendItem(title: "\(partition.label) (\(partition.fileSystem.rawValue))", color: Color.ntfsPartitionNTFS)
                legendItem(title: L10n.tr("part_type_unallocated", isChinese: isChinese), color: Color.ntfsCapacityFree)
                Spacer()
            }
            .padding(.top, 2)
        }
        .ntfsCardStyle(cornerRadius: 12, padding: 16)
    }

    private func legendItem(title: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
}
