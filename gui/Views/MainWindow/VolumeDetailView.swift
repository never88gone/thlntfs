import SwiftUI

/// Paragon 风格主窗口右侧卷详细信息与操作中心
public struct VolumeDetailView: View {
    @Binding public var partition: DiskPartition
    @ObservedObject public var diskOpController: DiskOperationController
    @ObservedObject public var startupManager: StartupDiskManager
    public var onMount: () -> Void
    public var onUnmount: () -> Void
    public var onOpenFinder: () -> Void

    @State private var showingEraseSheet: Bool = false
    @State private var showingVerifySheet: Bool = false
    @State private var showingRenameSheet: Bool = false
    @State private var showingStartupSheet: Bool = false
    @Environment(\.locale) private var locale

    private var isChinese: Bool {
        locale.identifier.hasPrefix("zh")
    }

    public init(
        partition: Binding<DiskPartition>,
        diskOpController: DiskOperationController,
        startupManager: StartupDiskManager = StartupDiskManager(),
        onMount: @escaping () -> Void = {},
        onUnmount: @escaping () -> Void = {},
        onOpenFinder: @escaping () -> Void = {}
    ) {
        self._partition = partition
        self.diskOpController = diskOpController
        self.startupManager = startupManager
        self.onMount = onMount
        self.onUnmount = onUnmount
        self.onOpenFinder = onOpenFinder
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 顶部大 Header 区域
                headerCard

                // 脏日志警告条
                if partition.isDirty {
                    dirtyWarningBanner
                }

                // 核心操作栏
                VolumeActionBarView(
                    partition: partition,
                    isBootable: startupManager.isBootable(partition: partition),
                    onMount: onMount,
                    onUnmount: onUnmount,
                    onOpenFinder: onOpenFinder,
                    onVerifyRepair: { showingVerifySheet = true },
                    onErase: { showingEraseSheet = true },
                    onSetStartupDisk: { showingStartupSheet = true }
                )

                // 物理磁盘全盘分区拓扑分布
                PartitionMapVisualizerView(partition: partition)

                // 存储容量分配卡片
                VolumeCapacityChartView(partition: partition)

                // 实时传输吞吐量仪表波形
                ThroughputVisualizerView(isMounted: partition.isMounted)

                // 详细属性与硬件参数卡片
                VolumeAttributesView(partition: partition)

                // 卷级偏好选项卡片
                VolumePreferencesView(
                    partition: $partition,
                    onSpotlightToggled: { disabled in
                        diskOpController.toggleSpotlight(partition: partition, disable: disabled)
                    }
                )
            }
            .padding(20)
        }
        .background(Color.ntfsMainBackground)
        .sheet(isPresented: $showingEraseSheet) {
            EraseVolumeSheet(
                partition: partition,
                diskOpController: diskOpController,
                onDismiss: { showingEraseSheet = false }
            )
        }
        .sheet(isPresented: $showingVerifySheet) {
            VerifyRepairSheet(
                partition: partition,
                diskOpController: diskOpController,
                onDismiss: { showingVerifySheet = false }
            )
        }
        .sheet(isPresented: $showingRenameSheet) {
            RenameVolumeSheet(
                partition: partition,
                diskOpController: diskOpController,
                onRenameConfirmed: { newName in
                    partition.label = newName
                    Task {
                        _ = await diskOpController.renameVolume(partition: partition, newLabel: newName)
                    }
                },
                onDismiss: { showingRenameSheet = false }
            )
        }
        .sheet(isPresented: $showingStartupSheet) {
            StartupDiskSheet(
                partition: partition,
                startupManager: startupManager,
                onDismiss: { showingStartupSheet = false }
            )
        }
    }

    private var headerCard: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(iconBackgroundColor)
                    .frame(width: 56, height: 56)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(iconColor.opacity(0.2), lineWidth: 1)
                    )

                Image(systemName: iconName)
                    .font(.system(size: 28))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(partition.label)
                        .font(.system(size: 22, weight: .bold))

                    Button(action: { showingRenameSheet = true }) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(L10n.tr("rename_tooltip", isChinese: isChinese))
                    .disabled(partition.isInternal)
                }

                HStack(spacing: 8) {
                    Text("\(partition.fileSystem.rawValue) \(L10n.tr("volume_suffix", isChinese: isChinese))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)

                    Text("·")
                        .foregroundColor(.secondary)

                    Text("/dev/\(partition.bsdName)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)

                    Text("·")
                        .foregroundColor(.secondary)

                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10))
                        Text(partition.busProtocol.rawValue)
                    }
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.ntfsBadgeBackground)
                    .clipShape(Capsule())
                }
            }

            Spacer()

            // 挂载状态胶囊
            HStack(spacing: 6) {
                Circle()
                    .fill(statusDotColor)
                    .frame(width: 8, height: 8)
                Text(statusText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(statusDotColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(statusDotColor.opacity(0.12))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(statusDotColor.opacity(0.25), lineWidth: 1)
            )
        }
        .padding(18)
        .ntfsCardStyle(cornerRadius: 14, padding: 0)
    }

    private var dirtyWarningBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Color.ntfsYellow)
                .font(.system(size: 22))

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.tr("dirty_warning_title", isChinese: isChinese))
                    .font(.system(size: 13, weight: .semibold))
                Text(L10n.tr("dirty_warning_banner", isChinese: isChinese))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(L10n.tr("verify_and_repair", isChinese: isChinese)) {
                showingVerifySheet = true
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.ntfsBlue)
            .controlSize(.small)
            .shadow(color: Color.ntfsBlue.opacity(0.2), radius: 3, x: 0, y: 1)
        }
        .padding(14)
        .background(Color.ntfsYellow.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.ntfsYellow.opacity(0.35), lineWidth: 1)
        )
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
        if !partition.isMounted {
            return .secondary
        }
        if partition.isDirty {
            return Color.ntfsYellow
        }
        if partition.isReadOnly {
            return Color.ntfsOrange
        }
        return Color.ntfsGreen
    }

    private var statusText: String {
        if !partition.isMounted {
            return L10n.tr("status_unmounted", isChinese: isChinese)
        }
        if partition.isDirty {
            return L10n.tr("status_dirty_readonly", isChinese: isChinese)
        }
        if partition.isReadOnly {
            return L10n.tr("status_readonly_mounted", isChinese: isChinese)
        }
        return L10n.tr("status_normal_rw", isChinese: isChinese)
    }
}
