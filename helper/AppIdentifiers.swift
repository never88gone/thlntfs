import Foundation

/// 全局唯一事实来源：包名与特权辅助服务标识配置 (Single Source of Truth)
/// 全工程所有主 App、特权 Helper、测试套件均通过本配置引用，严禁散落硬编码字符串。
public enum AppIdentifiers {
    /// 主应用 Bundle Identifier (统一唯一配置点)
    public static let mainAppBundleId = "com.never88gone.thlntfs"

    /// 特权辅助程序 Bundle Identifier
    public static let helperBundleId = "\(mainAppBundleId).helper"

    /// 特权辅助程序 Mach 服务名称 (XPC)
    public static let helperMachServiceName = helperBundleId

    /// 设置项 UserDefaults 键名前缀
    public static let settingsKeyPrefix = "\(mainAppBundleId).settings"

    /// 全局通知事件名称前缀
    public static let notificationPrefix = mainAppBundleId

    /// 统一通知名称定义
    public static let openMainWindowNotification = "\(notificationPrefix).open-main-window"
    public static let openSettingsNotification = "\(notificationPrefix).open-settings"
}

extension Notification.Name {
    public static let thlntfsOpenMainWindow = Notification.Name(AppIdentifiers.openMainWindowNotification)
    public static let thlntfsOpenSettings = Notification.Name(AppIdentifiers.openSettingsNotification)
}

