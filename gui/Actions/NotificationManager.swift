import Foundation
import UserNotifications

/// 负责调度 macOS 系统通知中心推送的通知管理器
@MainActor
public final class NotificationManager: ObservableObject {
    public static let shared = NotificationManager()

    @Published public var isAuthorized: Bool = false

    public var isSupported: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    public init() {
        if isSupported {
            checkAuthorization()
        }
    }

    /// 检查并请求系统通知权限
    public func requestAuthorization() {
        guard isSupported else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            Task { @MainActor in
                self?.isAuthorized = granted
            }
        }
    }

    public func checkAuthorization() {
        guard isSupported else { return }
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            let isAuth = (settings.authorizationStatus == .authorized)
            Task { @MainActor in
                self?.isAuthorized = isAuth
            }
        }
    }

    /// 发送卷挂载成功通知
    public func postMountSuccess(volumeLabel: String, isReadOnly: Bool) {
        guard isSupported else { return }
        let mode = isReadOnly ? L10n.tr("attr_read_only_val") : L10n.tr("attr_read_write_val")
        let content = UNMutableNotificationContent()
        content.title = L10n.tr("notify_mounted_title")
        content.body = L10n.tr("notify_mounted_body", volumeLabel, mode)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "ntfs_mount_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// 发送卷安全卸载通知
    public func postUnmountSuccess(volumeLabel: String) {
        guard isSupported else { return }
        let content = UNMutableNotificationContent()
        content.title = L10n.tr("notify_unmounted_title")
        content.body = L10n.tr("notify_unmounted_body", volumeLabel)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "ntfs_unmount_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// 发送脏日志保护性只读警告通知
    public func postDirtyJournalWarning(volumeLabel: String) {
        guard isSupported else { return }
        let content = UNMutableNotificationContent()
        content.title = L10n.tr("notify_dirty_title")
        content.body = L10n.tr("notify_dirty_body", volumeLabel)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "ntfs_dirty_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// 发送挂载错误通知
    public func postMountError(volumeLabel: String, error: String) {
        guard isSupported else { return }
        let content = UNMutableNotificationContent()
        content.title = L10n.tr("notify_error_title")
        content.body = L10n.tr("notify_error_body", volumeLabel, error)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "ntfs_error_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
