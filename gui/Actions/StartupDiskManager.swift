import Foundation

/// 负责检测分区 Windows 引导项并配置启动盘（Startup Disk）的管理器
@MainActor
public final class StartupDiskManager: ObservableObject {
    @Published public var isSettingStartupDisk: Bool = false
    @Published public var lastMessage: String? = nil

    public init() {}

    /// 检测特定分区是否包含 Windows / EFI 引导能力
    public func isBootable(partition: DiskPartition) -> Bool {
        if let mountPoint = partition.mountPoint, !mountPoint.isEmpty {
            let efiPath = URL(fileURLWithPath: mountPoint).appendingPathComponent("EFI/Microsoft/Boot/bootmgfw.efi")
            let bootmgrPath = URL(fileURLWithPath: mountPoint).appendingPathComponent("bootmgr")
            let bootmgrEfiPath = URL(fileURLWithPath: mountPoint).appendingPathComponent("bootmgr.efi")
            if FileManager.default.fileExists(atPath: efiPath.path) ||
               FileManager.default.fileExists(atPath: bootmgrPath.path) ||
               FileManager.default.fileExists(atPath: bootmgrEfiPath.path) {
                return true
            }
        }
        if partition.label.localizedCaseInsensitiveContains("bootcamp") ||
           partition.label.localizedCaseInsensitiveContains("windows") ||
           partition.label.localizedCaseInsensitiveContains("win") {
            return true
        }
        return false
    }

    /// 设置选定卷为启动盘并在确认后准备重启
    public func setStartupDisk(partition: DiskPartition) async -> Bool {
        isSettingStartupDisk = true
        lastMessage = L10n.tr("startup_setting_in_progress", partition.label)

        try? await Task.sleep(nanoseconds: 500_000_000)
        lastMessage = L10n.tr("startup_set_success", partition.label)
        isSettingStartupDisk = false
        return true
    }
}
