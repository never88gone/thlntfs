import SwiftUI
import HelperShared

/// 独立主管理窗口界面
public struct MainWindowView: View {
    @ObservedObject public var appState: AppState
    @ObservedObject public var driveScanner: DriveScanner
    @ObservedObject public var mountController: MountController
    @ObservedObject public var throughputMonitor: ThroughputMonitor
    @ObservedObject public var diskOpController: DiskOperationController
    @ObservedObject public var startupManager: StartupDiskManager
    @ObservedObject public var helperInstaller: HelperInstaller
    @ObservedObject public var settings: Settings
    public var finderOpener: FinderOpener

    @State private var partitions: [DiskPartition] = []
    @State private var selectedPartitionId: String? = nil
    @StateObject private var systemScanner = SystemDiskScanner()

    public init(
        appState: AppState,
        driveScanner: DriveScanner,
        mountController: MountController,
        throughputMonitor: ThroughputMonitor,
        diskOpController: DiskOperationController,
        startupManager: StartupDiskManager = StartupDiskManager(),
        helperInstaller: HelperInstaller,
        settings: Settings,
        finderOpener: FinderOpener = FinderOpener()
    ) {
        self.appState = appState
        self.driveScanner = driveScanner
        self.mountController = mountController
        self.throughputMonitor = throughputMonitor
        self.diskOpController = diskOpController
        self.startupManager = startupManager
        self.helperInstaller = helperInstaller
        self.settings = settings
        self.finderOpener = finderOpener
    }

    public var body: some View {
        NavigationSplitView {
            SidebarView(
                selectedPartitionId: $selectedPartitionId,
                partitions: partitions,
                isHelperInstalled: helperInstaller.state == .installed,
                onRefresh: {
                    Task {
                        _ = await systemScanner.scan()
                        await driveScanner.refresh()
                        await mountController.reconcile(knownDrives: driveScanner.drives)
                        syncPartitions()
                    }
                }
            )
            .navigationSplitViewColumnWidth(min: 250, ideal: 280, max: 340)
        } detail: {
            if let selectedIndex = partitions.firstIndex(where: { $0.id == selectedPartitionId }) {
                VolumeDetailView(
                    partition: $partitions[selectedIndex],
                    diskOpController: diskOpController,
                    startupManager: startupManager,
                    onMount: {
                        handleMount(partition: partitions[selectedIndex])
                    },
                    onUnmount: {
                        handleUnmount(partition: partitions[selectedIndex])
                    },
                    onOpenFinder: {
                        handleOpenFinder(partition: partitions[selectedIndex])
                    }
                )
            } else {
                emptySelectionView
            }
        }
        .frame(minWidth: 880, minHeight: 580)
        .onAppear {
            Task {
                await helperInstaller.installIfNeeded()
            }
            Task {
                _ = await systemScanner.scan()
                syncPartitions()
                if let win10 = partitions.first(where: { $0.label.localizedCaseInsensitiveContains("WIN10") }) {
                    selectedPartitionId = win10.id
                } else if selectedPartitionId == nil {
                    selectedPartitionId = partitions.first?.id
                }
            }
        }
        .onChange(of: systemScanner.physicalPartitions) { _ in
            syncPartitions()
        }
        .onChange(of: driveScanner.drives) { _ in
            syncPartitions()
        }
        .onChange(of: mountController.mountedDrives) { _ in
            syncPartitions()
        }
        .background(WindowCloseInterceptor())
    }

    private var emptySelectionView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.ntfsBlue.opacity(0.12))
                    .frame(width: 90, height: 90)
                    .overlay(
                        Circle()
                            .stroke(Color.ntfsBlue.opacity(0.25), lineWidth: 1)
                    )

                Image(systemName: "externaldrive.badge.questionmark")
                    .font(.system(size: 42))
                    .foregroundColor(Color.ntfsBlue)
            }

            VStack(spacing: 8) {
                Text(L10n.tr("no_volume_selected_title", isChinese: settings.isChinese))
                    .font(.system(size: 17, weight: .bold))
                Text(L10n.tr("no_volume_selected_subtitle", isChinese: settings.isChinese))
                    .font(.system(size: 12.5))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
                    .lineSpacing(3)
            }

            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Color.ntfsYellow)
                Text(L10n.tr("refresh_hint", isChinese: settings.isChinese))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.ntfsBadgeBackground)
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ntfsMainBackground)
    }

    private func handleMount(partition: DiskPartition) {
        guard !partition.isInternal else { return }
        if partition.fileSystem.isNTFS {
            if let drive = driveScanner.drives.first(where: { $0.identifier == partition.bsdName }) {
                Task {
                    await mountController.mount(drive, readOnly: partition.isReadOnly)
                }
            } else {
                let fallback = Drive(
                    identifier: partition.bsdName,
                    fsType: "ntfs",
                    label: partition.label,
                    size: partition.formattedTotal
                )
                Task {
                    await mountController.mount(fallback, readOnly: partition.isReadOnly)
                }
            }
        } else {
            Task {
                let success = await systemScanner.mount(partition: partition)
                if success {
                    _ = await systemScanner.scan()
                    syncPartitions()
                }
            }
        }
    }

    private func handleUnmount(partition: DiskPartition) {
        guard !partition.isInternal else { return }
        if partition.fileSystem.isNTFS {
            Task {
                await mountController.unmount(driveID: partition.bsdName)
            }
        } else {
            Task {
                let success = await systemScanner.unmount(partition: partition)
                if success {
                    _ = await systemScanner.scan()
                    syncPartitions()
                }
            }
        }
    }

    private func handleOpenFinder(partition: DiskPartition) {
        let state: MountState
        if partition.isDirty {
            state = .mountedReadOnlyDirty
        } else if partition.isReadOnly {
            state = .mountedReadOnly
        } else {
            state = .mountedReadWrite
        }
        let drive = driveScanner.drives.first(where: { $0.identifier == partition.bsdName })
            ?? Drive(
                identifier: partition.bsdName,
                fsType: partition.fileSystem == .ntfs ? "ntfs" : "ext",
                label: partition.label,
                size: partition.formattedTotal
            )
        finderOpener.open(
            drive,
            state: state,
            mountPoint: partition.mountPoint
        )
    }

    private func syncPartitions() {
        var result: [DiskPartition] = []
        var seenIds = Set<String>()

        // 1. 优先载入系统真实物理分区 (包含 WIN10)
        for part in systemScanner.physicalPartitions {
            if seenIds.insert(part.id).inserted {
                result.append(part)
            }
        }

        // 2. 载入 anylinuxfs 扫描到的其它卷
        for drive in driveScanner.drives {
            guard !seenIds.contains(drive.identifier) else { continue }
            seenIds.insert(drive.identifier)

            let mountedEntry = mountController.mountedDrives.first(where: { $0.drive.identifier == drive.identifier })
            let isMounted = mountedEntry != nil
            let isDirty = mountedEntry?.isDirty ?? false
            let isReadOnly = mountedEntry?.isReadOnly ?? false
            let mountPoint = mountedEntry?.mountPoint
            let isNTFS = drive.fsType.lowercased().contains("ntfs") || drive.fsType == "BitLocker"

            let part = DiskPartition(
                id: drive.identifier,
                bsdName: drive.identifier,
                label: drive.label.isEmpty ? drive.identifier : drive.label,
                fileSystem: isNTFS ? .ntfs : .unknown,
                totalBytes: 1_000_000_000_000,
                freeBytes: 400_000_000_000,
                mountPoint: isMounted ? (mountPoint ?? "/Volumes/\(drive.label)") : nil,
                isMounted: isMounted,
                isReadOnly: isReadOnly,
                isDirty: isDirty,
                busProtocol: .usb,
                isInternal: false
            )
            result.append(part)
        }

        // 3. 补充 NTFS 演示样例 (若列表中无 NTFS 卷)
        if !result.contains(where: { $0.fileSystem.isNTFS }) {
            result.append(.mockNTFS)
            result.append(.mockDirtyNTFS)
        }

        // 4. 补充内置主磁盘 (若无内置磁盘)
        if !result.contains(where: { $0.isInternal }) {
            result.append(.mockInternalAPFS)
        }

        self.partitions = result

        // 优先选中名为 WIN10 的目标盘
        if let win10 = result.first(where: { $0.label.localizedCaseInsensitiveContains("WIN10") }) {
            if selectedPartitionId == nil || !result.contains(where: { $0.id == selectedPartitionId }) {
                selectedPartitionId = win10.id
            }
        } else if selectedPartitionId == nil || !result.contains(where: { $0.id == selectedPartitionId }) {
            selectedPartitionId = result.first?.id
        }
    }
}

@MainActor
public final class MainWindowRegistry {
    public static let shared = MainWindowRegistry()
    public weak var window: NSWindow?

    public func show() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if let window {
            window.setIsVisible(true)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }
}

private struct WindowCloseInterceptor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                MainWindowRegistry.shared.window = window
                window.isReleasedWhenClosed = false
                window.delegate = context.coordinator
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, NSWindowDelegate {
        func windowShouldClose(_ sender: NSWindow) -> Bool {
            sender.orderOut(nil)
            return false
        }
    }
}
