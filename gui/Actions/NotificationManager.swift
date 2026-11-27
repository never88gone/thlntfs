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
        Task { @MainActor [weak self] in
            let granted = await Self.requestAuthorizationOffMain()
            self?.isAuthorized = granted
        }
    }

    public func checkAuthorization() {
        guard isSupported else { return }
        Task { @MainActor [weak self] in
            let isAuth = await Self.checkAuthorizationOffMain()
            self?.isAuthorized = isAuth
        }
    }

    // `nonisolated`: UserNotifications invokes completion blocks on its own background
    // dispatch queue, never on the main actor. Calling into it inside a `nonisolated`
    // function prevents Swift 6 from synthesizing a `@MainActor` isolation check (`SIGTRAP`).
    private nonisolated static func requestAuthorizationOffMain() async -> Bool {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    private nonisolated static func checkAuthorizationOffMain() async -> Bool {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus == .authorized)
            }
        }
    }

    private nonisolated static func enqueueNotification(_ request: UNNotificationRequest) {
        UNUserNotificationCenter.current().add(request) { _ in }
    }

    private func postNotification(prefix: String, title: String, body: String) {
        guard isSupported else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "\(prefix)_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        Self.enqueueNotification(request)
    }

    /// 发送卷挂载成功通知
    public func postMountSuccess(volumeLabel: String, isReadOnly: Bool) {
        let mode = isReadOnly ? L10n.tr("attr_read_only_val") : L10n.tr("attr_read_write_val")
        postNotification(
            prefix: "ntfs_mount",
            title: L10n.tr("notify_mounted_title"),
            body: L10n.tr("notify_mounted_body", volumeLabel, mode)
        )
    }

    /// 发送卷安全卸载通知
    public func postUnmountSuccess(volumeLabel: String) {
        postNotification(
            prefix: "ntfs_unmount",
            title: L10n.tr("notify_unmounted_title"),
            body: L10n.tr("notify_unmounted_body", volumeLabel)
        )
    }

    /// 发送脏日志保护性只读警告通知
    public func postDirtyJournalWarning(volumeLabel: String) {
        postNotification(
            prefix: "ntfs_dirty",
            title: L10n.tr("notify_dirty_title"),
            body: L10n.tr("notify_dirty_body", volumeLabel)
        )
    }

    /// 发送挂载错误通知
    public func postMountError(volumeLabel: String, error: String) {
        postNotification(
            prefix: "ntfs_error",
            title: L10n.tr("notify_error_title"),
            body: L10n.tr("notify_error_body", volumeLabel, error)
        )
    }
}
