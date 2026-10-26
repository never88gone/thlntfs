import Foundation
import SwiftUI

/// 负责监听物理磁盘插入并执行自动静默挂载的管理器
@MainActor
public final class AutoMountManager: ObservableObject {
    @Published public var isAutoMountEnabled: Bool = true
    private var handledDeviceIdentifiers: Set<String> = []

    public init(isAutoMountEnabled: Bool = true) {
        self.isAutoMountEnabled = isAutoMountEnabled
    }

    /// 评估并执行自动挂载流程
    public func handleDiscoveredDrives(
        drives: [Drive],
        mountController: MountController,
        notificationManager: NotificationManager = .shared
    ) {
        guard isAutoMountEnabled else { return }

        for drive in drives {
            let identifier = drive.identifier
            let isAlreadyMounted = mountController.mountedDrives.contains(where: { $0.drive.identifier == identifier })

            if !isAlreadyMounted && !handledDeviceIdentifiers.contains(identifier) {
                handledDeviceIdentifiers.insert(identifier)
                Task {
                    await mountController.mount(drive, readOnly: false)
                    notificationManager.postMountSuccess(
                        volumeLabel: drive.label.isEmpty ? drive.identifier : drive.label,
                        isReadOnly: false
                    )
                }
            }
        }

        // 清理已拔出设备的历史标记
        let currentIdentifiers = Set(drives.map(\.identifier))
        handledDeviceIdentifiers = handledDeviceIdentifiers.intersection(currentIdentifiers)
    }
}
