import SwiftUI
import HelperShared

// MARK: - 全局集中 SwiftUI 视图预览 (All Previews)
// 遵循用户规范：所有 SwiftUI 的 #Preview 统一集中收录于本文件，方便随时预览与调试组件，
// 保持业务 View 源文件轻量且行数受控。

// MARK: - 基础样式与通用组件预览
#Preview("Card Style - 卡片微高光样式") {
    VStack(spacing: 16) {
        Text("卡片样式预览").font(.headline)
        Text("双层微描边、顶部微高光与毛玻璃底色").foregroundColor(.secondary)
    }
    .frame(width: 340, height: 180)
    .ntfsCardStyle()
    .padding()
}

#Preview("FDA Prompt - 完全磁盘访问引导") {
    FDAPromptView(onOpenSettings: {}, onCancel: {})
}

#Preview("Diagnose Panel - 诊断报告面板") {
    DiagnosePanel(runner: DiagnoseRunner())
        .frame(width: 320)
        .padding()
}

// MARK: - 偏好设置选项卡预览
#Preview("Preferences - 偏好设置主窗口") {
    MainPreferencesWindowView(
        settings: Settings(),
        helperInstaller: HelperInstaller(),
        helperUninstaller: HelperUninstaller(onUninstallComplete: {}),
        diagnoseRunner: DiagnoseRunner()
    )
}

#Preview("Preferences - 常规设置选项卡") {
    GeneralSettingsTab(settings: Settings())
        .frame(width: 580, height: 480)
}

#Preview("Preferences - 驱动与性能选项卡") {
    DriverPerformanceTab(settings: Settings())
        .frame(width: 580, height: 480)
}

#Preview("Preferences - 特权服务与安全隔离") {
    SecurityIsolationTab(
        helperInstaller: HelperInstaller(),
        helperUninstaller: HelperUninstaller(onUninstallComplete: {})
    )
    .frame(width: 580, height: 480)
}

#Preview("Preferences - 系统诊断与关于选项卡") {
    DiagnosticsAboutTab(diagnoseRunner: DiagnoseRunner())
        .frame(width: 580, height: 480)
}

// MARK: - 功能弹窗 (Sheets) 预览
#Preview("Sheet - 抹掉并格式化分区") {
    EraseVolumeSheet(
        partition: .mockNTFS,
        diskOpController: DiskOperationController(),
        onDismiss: {}
    )
}

#Preview("Sheet - 卷标重命名") {
    RenameVolumeSheet(
        partition: .mockNTFS,
        diskOpController: DiskOperationController(),
        onRenameConfirmed: { _ in },
        onDismiss: {}
    )
}

#Preview("Sheet - 设为系统启动盘") {
    StartupDiskSheet(
        partition: .mockNTFS,
        startupManager: StartupDiskManager(),
        onDismiss: {}
    )
}

#Preview("Sheet - 急救与修复") {
    VerifyRepairSheet(
        partition: .mockDirtyNTFS,
        diskOpController: DiskOperationController(),
        onDismiss: {}
    )
}

// MARK: - 主管理窗口及子看板预览
#Preview("MainWindow - 主管理窗口总览") {
    MainWindowView(
        appState: AppState(),
        driveScanner: DriveScanner(),
        mountController: MountController(appState: AppState()),
        throughputMonitor: ThroughputMonitor(),
        diskOpController: DiskOperationController(),
        startupManager: StartupDiskManager(),
        helperInstaller: HelperInstaller(),
        settings: Settings()
    )
}

#Preview("MainWindow - 侧边栏列表") {
    SidebarView(
        selectedPartitionId: .constant(DiskPartition.mockNTFS.id),
        partitions: [.mockNTFS, .mockDirtyNTFS, .mockExFAT, .mockInternalAPFS]
    )
    .frame(width: 270, height: 520)
}

#Preview("MainWindow - 侧边栏分区项") {
    VStack(spacing: 8) {
        SidebarDiskRow(partition: .mockNTFS, isSelected: true)
        SidebarDiskRow(partition: .mockDirtyNTFS, isSelected: false)
        SidebarDiskRow(partition: .mockExFAT, isSelected: false)
        SidebarDiskRow(partition: .mockInternalAPFS, isSelected: false)
    }
    .frame(width: 270)
    .padding()
}

#Preview("MainWindow - 分区详情大看板") {
    VolumeDetailView(
        partition: .constant(.mockDirtyNTFS),
        diskOpController: DiskOperationController(),
        startupManager: StartupDiskManager()
    )
    .frame(width: 680, height: 850)
}

#Preview("MainWindow - 动作按钮条") {
    VStack(spacing: 16) {
        VolumeActionBarView(partition: .mockNTFS, isBootable: true)
        VolumeActionBarView(partition: .mockDirtyNTFS, isBootable: false)
    }
    .padding()
    .frame(width: 720)
}

#Preview("MainWindow - 分区地图拓扑图") {
    PartitionMapVisualizerView(partition: .mockNTFS)
        .padding()
        .frame(width: 600)
}

#Preview("MainWindow - 容量占比图") {
    VStack(spacing: 16) {
        VolumeCapacityChartView(partition: .mockNTFS)
        VolumeCapacityChartView(partition: .mockDirtyNTFS)
    }
    .padding()
    .frame(width: 580)
}

#Preview("MainWindow - 分区属性参数看板") {
    VStack(spacing: 16) {
        VolumeAttributesView(partition: .mockNTFS)
        VolumeAttributesView(partition: .mockDirtyNTFS)
    }
    .padding()
    .frame(width: 580)
}

#Preview("MainWindow - 驱动与装载偏好设置") {
    VolumePreferencesView(partition: .constant(.mockNTFS))
        .padding()
        .frame(width: 580)
}

#Preview("MainWindow - 实时吞吐量波形图") {
    VStack(spacing: 16) {
        ThroughputVisualizerView(isMounted: true)
        ThroughputVisualizerView(isMounted: false)
    }
    .padding()
    .frame(width: 600)
}
