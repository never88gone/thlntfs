import SwiftUI

/// 侧边栏单个磁盘/卷列表项，展示卷标、文件系统类型、容量进度与状态徽标
public struct SidebarDiskRow: View {
    public let partition: DiskPartition
    public let isSelected: Bool
    @Environment(\.locale) private var locale

    private var isChinese: Bool {
        locale.identifier.hasPrefix("zh")
    }

    public init(partition: DiskPartition, isSelected: Bool) {
        self.partition = partition
        self.isSelected = isSelected
    }

    public var body: some View {
        HStack(spacing: 12) {
            // 图标徽标底座 (双层圆角与状态呼吸指示灯)
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(iconBackgroundColor)
                    .frame(width: 36, height: 36)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(iconColor.opacity(0.18), lineWidth: 1)
                    )

                Image(systemName: iconName)
                    .font(.system(size: 19))
                    .foregroundColor(iconColor)
                    .frame(width: 36, height: 36)

                if partition.isMounted {
                    Circle()
                        .fill(statusDotColor)
                        .frame(width: 9, height: 9)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                        .offset(x: 2, y: 2)
                        .shadow(color: statusDotColor.opacity(0.4), radius: 2, x: 0, y: 1)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(partition.label)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Spacer()

                    if partition.isMounted {
                        Text(statusBadgeText)
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(statusBadgeBackground)
                            .foregroundColor(statusBadgeForeground)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(statusBadgeForeground.opacity(0.2), lineWidth: 0.5)
                            )
                    }
                }

                HStack(spacing: 4) {
                    Text(partition.fileSystem.rawValue)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    Text("·")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Text(partition.formattedTotal)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                // 微型容量条 (渐变色彩与微反光)
                if partition.totalBytes > 0 {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.ntfsCapacityFree)
                                .frame(height: 3.5)
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [progressBarColor, progressBarColor.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(
                                    width: max(0, min(geo.size.width, geo.size.width * CGFloat(partition.usagePercentage))),
                                    height: 3.5
                                )
                        }
                    }
                    .frame(height: 3.5)
                }
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.ntfsSidebarSelection : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isSelected ? Color.ntfsBlue.opacity(0.2) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }

    private var iconName: String {
        if partition.isInternal {
            return "internaldrive"
        }
        switch partition.busProtocol {
        case .thunderbolt:
            return "bolt.horizontal.fill"
        default:
            return "externaldrive.fill"
        }
    }

    private var iconColor: Color {
        if partition.fileSystem.isNTFS {
            return Color.ntfsBlue
        } else if partition.isInternal {
            return .secondary
        } else {
            return Color.ntfsPurple
        }
    }

    private var iconBackgroundColor: Color {
        iconColor.opacity(0.12)
    }

    private var statusDotColor: Color {
        if partition.isDirty {
            return Color.ntfsYellow
        } else if partition.isReadOnly {
            return Color.ntfsOrange
        } else {
            return Color.ntfsGreen
        }
    }

    private var progressBarColor: Color {
        if partition.usagePercentage > 0.90 {
            return Color.ntfsCapacityWarning
        }
        return Color.ntfsCapacityUsed
    }

    private var statusBadgeText: String {
        if partition.isDirty {
            return L10n.tr("status_dirty", isChinese: isChinese)
        } else if partition.isReadOnly {
            return L10n.tr("status_read_only", isChinese: isChinese)
        } else if !partition.isMounted {
            return L10n.tr("status_unmounted", isChinese: isChinese)
        } else {
            return L10n.tr("status_read_write", isChinese: isChinese)
        }
    }

    private var statusBadgeBackground: Color {
        if partition.isDirty {
            return Color.ntfsYellow.opacity(0.15)
        } else if partition.isReadOnly {
            return Color.ntfsOrange.opacity(0.15)
        } else {
            return Color.ntfsGreen.opacity(0.15)
        }
    }

    private var statusBadgeForeground: Color {
        if partition.isDirty {
            return Color.ntfsYellow
        } else if partition.isReadOnly {
            return Color.ntfsOrange
        } else {
            return Color.ntfsGreen
        }
    }
}
