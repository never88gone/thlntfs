import Foundation
import HelperShared

/// 统一的多语言字符串加载器，从 Localizable.strings 资源文件动态读取中英文翻译
public enum L10n {
    /// 语言资源字典内存缓存 [语言代码: [Key: 本地化文本]]
    nonisolated(unsafe) private static var cache: [String: [String: String]] = [:]
    private static let lock = NSLock()

    /// 根据当前语言环境获取对应 key 的本地化字符串
    public static func string(_ key: String, isChinese: Bool, default fallback: String = "") -> String {
        let lang = isChinese ? "zh-Hans" : "en"
        let table = loadTable(for: lang)
        if let val = table[key], !val.isEmpty {
            return val
        }
        // 如果未命中，尝试从兜底语言中读取
        let fallbackTable = isChinese ? loadTable(for: "en") : loadTable(for: "zh-Hans")
        return fallbackTable[key] ?? (fallback.isEmpty ? key : fallback)
    }

    private static func resolveIsChinese(_ override: Bool?) -> Bool {
        if let override { return override }
        let defaults = UserDefaults.standard
        let langKey = "\(AppIdentifiers.settingsKeyPrefix).language"
        if let raw = defaults.string(forKey: langKey) ?? defaults.string(forKey: "app_language") {
            if raw == "zh-Hans" || raw == "zh" { return true }
            if raw == "en" { return false }
        }
        if let appleLangs = defaults.stringArray(forKey: "AppleLanguages"), let first = appleLangs.first?.lowercased() {
            if first.hasPrefix("zh") { return true }
            if first.hasPrefix("en") { return false }
        }
        if let primary = Locale.preferredLanguages.first?.lowercased() {
            if primary.hasPrefix("zh") || primary.contains("chinese") { return true }
        }
        return Locale.current.identifier.lowercased().hasPrefix("zh")
    }

    /// 标准化通用国际化取值入口：直接从 Localizable.strings 资源文件读取对应 key 的文本
    public static func tr(_ key: String, isChinese: Bool? = nil) -> String {
        let isZh = resolveIsChinese(isChinese)
        return string(key, isChinese: isZh)
    }

    /// 带有 1 个格式化参数的通用国际化取值入口
    public static func tr(_ key: String, _ arg1: CVarArg, isChinese: Bool? = nil) -> String {
        let isZh = resolveIsChinese(isChinese)
        let format = string(key, isChinese: isZh)
        return String(format: format, arg1)
    }

    /// 带有 2 个格式化参数的通用国际化取值入口
    public static func tr(_ key: String, _ arg1: CVarArg, _ arg2: CVarArg, isChinese: Bool? = nil) -> String {
        let isZh = resolveIsChinese(isChinese)
        let format = string(key, isChinese: isZh)
        return String(format: format, arg1, arg2)
    }

    /// 带有任意数量格式化参数的通用国际化取值入口
    public static func trFormat(_ key: String, args: [CVarArg], isChinese: Bool? = nil) -> String {
        let isZh = resolveIsChinese(isChinese)
        let format = string(key, isChinese: isZh)
        return String(format: format, arguments: args)
    }

    /// 双语回退辅助方法
    @inlinable
    public static func text(_ chinese: String, en english: String, isChinese: Bool) -> String {
        isChinese ? chinese : english
    }

    // MARK: - 资源加载核心
    private static func loadTable(for lang: String) -> [String: String] {
        lock.lock()
        defer { lock.unlock() }

        if let existing = cache[lang] {
            return existing
        }

        var loaded: [String: String]? = nil

        // 1. 尝试从 Bundle.main 加载 (打包后的 .app)
        if let bundlePath = Bundle.main.path(forResource: lang, ofType: "lproj"),
           let bundle = Bundle(path: bundlePath),
           let file = bundle.path(forResource: "Localizable", ofType: "strings"),
           let dict = NSDictionary(contentsOfFile: file) as? [String: String] {
            loaded = dict
        }

        // 2. 尝试从 Bundle.main/Contents/Resources/\(lang).lproj 加载
        if loaded == nil,
           let resPath = Bundle.main.resourcePath {
            let path = (resPath as NSString).appendingPathComponent("\(lang).lproj/Localizable.strings")
            if let dict = NSDictionary(contentsOfFile: path) as? [String: String] {
                loaded = dict
            }
        }

        // 3. 尝试从源码工程目录相对路径加载 (开发环境与 swift test 单元测试)
        if loaded == nil {
            let fileURL = URL(fileURLWithPath: #filePath)
            let projectResources = fileURL
                .deletingLastPathComponent() // Style
                .deletingLastPathComponent() // gui
                .appendingPathComponent("Resources/\(lang).lproj/Localizable.strings")
            if let dict = NSDictionary(contentsOfFile: projectResources.path) as? [String: String] {
                loaded = dict
            }
        }

        // 4. 尝试当前工作目录下相对路径加载
        if loaded == nil {
            let cwdPath = "gui/Resources/\(lang).lproj/Localizable.strings"
            if let dict = NSDictionary(contentsOfFile: cwdPath) as? [String: String] {
                loaded = dict
            }
        }

        let result = loaded ?? [:]
        cache[lang] = result
        return result
    }

    // MARK: - 应用名称与主窗口
    public static func appName(isChinese: Bool = true) -> String {
        string("app_name", isChinese: isChinese, default: "THLNTFS")
    }

    public static func mainWindowTitle(isChinese: Bool = true) -> String {
        string("main_window_title", isChinese: isChinese, default: isChinese ? "THLNTFS 磁盘管理" : "THLNTFS Disk Manager")
    }

    public static func openMainWindow(isChinese: Bool) -> String {
        string("open_main_window", isChinese: isChinese, default: isChinese ? "打开主管理窗口" : "Open Main Window")
    }

    // MARK: - 常用导航与选项卡
    public static func general(isChinese: Bool) -> String {
        string("general", isChinese: isChinese, default: isChinese ? "常规" : "General")
    }

    public static func driverPerformance(isChinese: Bool) -> String {
        string("driver_performance", isChinese: isChinese, default: isChinese ? "驱动与性能" : "Driver & Performance")
    }

    public static func securityIsolation(isChinese: Bool) -> String {
        string("security_isolation", isChinese: isChinese, default: isChinese ? "安全与隔离" : "Security & Isolation")
    }

    public static func diagnosticsAbout(isChinese: Bool) -> String {
        string("diagnostics_about", isChinese: isChinese, default: isChinese ? "诊断与关于" : "Diagnostics & About")
    }

    // MARK: - 常用动作按钮
    public static func refresh(isChinese: Bool) -> String {
        string("refresh", isChinese: isChinese, default: isChinese ? "刷新" : "Refresh")
    }

    public static func diagnose(isChinese: Bool) -> String {
        string("diagnose", isChinese: isChinese, default: isChinese ? "诊断" : "Diagnose")
    }

    public static func quit(isChinese: Bool) -> String {
        string("quit", isChinese: isChinese, default: isChinese ? "退出" : "Quit")
    }

    public static func back(isChinese: Bool) -> String {
        string("back", isChinese: isChinese, default: isChinese ? "返回" : "Back")
    }

    public static func settings(isChinese: Bool) -> String {
        string("settings", isChinese: isChinese, default: isChinese ? "偏好设置" : "Settings")
    }

    public static func cancel(isChinese: Bool) -> String {
        string("cancel", isChinese: isChinese, default: isChinese ? "取消" : "Cancel")
    }

    public static func retry(isChinese: Bool) -> String {
        string("retry", isChinese: isChinese, default: isChinese ? "重试" : "Retry")
    }

    // MARK: - 卷操作按钮
    public static func mount(isChinese: Bool) -> String {
        string("mount", isChinese: isChinese, default: isChinese ? "挂载 (读/写)" : "Mount (Read/Write)")
    }

    public static func quickMount(isChinese: Bool) -> String {
        string("quick_mount", isChinese: isChinese, default: isChinese ? "挂载" : "Mount")
    }

    public static func unmount(isChinese: Bool) -> String {
        string("unmount", isChinese: isChinese, default: isChinese ? "卸载" : "Unmount")
    }

    public static func mountAnyway(isChinese: Bool) -> String {
        string("mount_anyway", isChinese: isChinese, default: isChinese ? "仍然以读写模式挂载…" : "Mount read/write anyway…")
    }

    public static func openInFinder(isChinese: Bool) -> String {
        string("open_in_finder", isChinese: isChinese, default: isChinese ? "在访达打开" : "Open in Finder")
    }

    public static func verifyAndRepair(isChinese: Bool) -> String {
        string("verify_and_repair", isChinese: isChinese, default: isChinese ? "验证与修复" : "Verify & Repair")
    }

    public static func erase(isChinese: Bool) -> String {
        string("erase", isChinese: isChinese, default: isChinese ? "抹掉" : "Erase")
    }

    public static func setStartupDisk(isChinese: Bool) -> String {
        string("set_startup_disk", isChinese: isChinese, default: isChinese ? "设为启动盘" : "Set as Startup Disk")
    }

    // MARK: - 语言偏好设置
    public static func languageSection(isChinese: Bool) -> String {
        string("language_section", isChinese: isChinese, default: isChinese ? "界面语言与偏好" : "Interface Language")
    }

    public static func languageTitle(isChinese: Bool) -> String {
        string("language_title", isChinese: isChinese, default: isChinese ? "应用界面语言" : "App Display Language")
    }

    public static func languageSubtitle(isChinese: Bool) -> String {
        string("language_subtitle", isChinese: isChinese, default: isChinese ? "设置主界面、菜单栏助手与偏好设置的显示语言" : "Select display language for main window and settings")
    }

    public static func languageSystemName(isChinese: Bool) -> String {
        string("lang_system", isChinese: isChinese, default: isChinese ? "跟随系统" : "System Default")
    }

    public static func languageEnglishName(isChinese: Bool) -> String {
        string("lang_english", isChinese: isChinese, default: isChinese ? "英文 (English)" : "English")
    }

    public static func languageChineseName(isChinese: Bool) -> String {
        string("lang_chinese", isChinese: isChinese, default: isChinese ? "中文 (简体中文)" : "Simplified Chinese")
    }

    // MARK: - 菜单栏常驻卡片状态
    public static func noDrivesFound(isChinese: Bool) -> String {
        string("no_drives_found", isChinese: isChinese, default: isChinese ? "未发现磁盘" : "No drives found")
    }

    public static func drivesDetected(count: Int, isChinese: Bool) -> String {
        let format = string("drives_detected_format", isChinese: isChinese, default: isChinese ? "已检测到 %d 个磁盘" : "%d drive(s) detected")
        return String(format: format, count)
    }

    public static func mounting(isChinese: Bool) -> String {
        string("mounting", isChinese: isChinese, default: isChinese ? "正在挂载…" : "Mounting…")
    }

    public static func mountedReadWrite(isChinese: Bool) -> String {
        string("mounted_read_write", isChinese: isChinese, default: isChinese ? "已读写挂载" : "Mounted read/write")
    }

    public static func mountedReadOnly(isChinese: Bool) -> String {
        string("mounted_read_only", isChinese: isChinese, default: isChinese ? "已只读挂载" : "Mounted read-only")
    }

    public static func mountVerificationNeeded(isChinese: Bool) -> String {
        string("mount_verification_needed", isChinese: isChinese, default: isChinese ? "挂载状态待验证" : "Mount state needs verification")
    }

    public static func error(isChinese: Bool) -> String {
        string("error", isChinese: isChinese, default: isChinese ? "错误" : "Error")
    }

    // MARK: - 菜单栏卡片空状态与设备列表
    public static func emptyStateTitle(isChinese: Bool) -> String {
        string("empty_state_title", isChinese: isChinese, default: isChinese ? "未连接 NTFS / ext 磁盘" : "No NTFS / ext drives connected")
    }

    public static func emptyStateSubtitle(isChinese: Bool) -> String {
        string("empty_state_subtitle", isChinese: isChinese, default: isChinese ? "连接 NTFS 或 ext 磁盘以开始使用" : "Connect an NTFS or ext drive to\nget started")
    }

    public static func otherAvailableDevices(isChinese: Bool) -> String {
        string("other_available_devices", isChinese: isChinese, default: isChinese ? "其他可用设备" : "Other available devices")
    }

    // MARK: - 脏日志警告与弹窗
    public static func dirtyWarningTitle(isChinese: Bool) -> String {
        string("dirty_warning_title", isChinese: isChinese, default: isChinese ? "检测到未正常卸载日志" : "Unclean journal detected")
    }

    public static func dirtyWarningBanner(isChinese: Bool) -> String {
        string("dirty_warning_banner", isChinese: isChinese, default: isChinese ? "已作为只读模式挂载 — 磁盘存在未正常卸载的日志。在 Windows 中安全弹出以启用写入。" : "Mounted read-only — drive has an unclean journal. Eject safely in Windows to enable writing.")
    }

    public static func dirtyRiskCopy(isChinese: Bool) -> String {
        string("dirty_risk_copy", isChinese: isChinese, default: isChinese ? "强制以读写模式挂载存在未清除日志的磁盘可能导致数据损坏。请在充分了解风险后继续。" : "Mounting a drive with an unclean journal read/write risks data corruption. Only continue if you understand the risk.")
    }

    public static func dirtyConfirmDialogTitle(isChinese: Bool) -> String {
        string("dirty_confirm_dialog_title", isChinese: isChinese, default: isChinese ? "确定仍然以读写模式挂载吗？" : "Mount read/write anyway?")
    }

    public static func dirtyConfirmAction(isChinese: Bool) -> String {
        string("dirty_confirm_action", isChinese: isChinese, default: isChinese ? "以读写模式挂载" : "Mount Read/Write")
    }

    // MARK: - 帮助程序与初始化安装
    public static func setupRequired(isChinese: Bool) -> String {
        string("setup_required", isChinese: isChinese, default: isChinese ? "需要配置" : "Setup required")
    }

    public static func setupIncomplete(isChinese: Bool) -> String {
        string("setup_incomplete", isChinese: isChinese, default: isChinese ? "配置未完成" : "Setup incomplete")
    }

    public static func checkingHelper(isChinese: Bool) -> String {
        string("checking_helper", isChinese: isChinese, default: isChinese ? "正在检查特权辅助服务…" : "Checking privileged helper…")
    }

    public static func waitingForAuth(isChinese: Bool) -> String {
        string("waiting_for_auth", isChinese: isChinese, default: isChinese ? "等待系统授权…" : "Waiting for authorization…")
    }

    public static func helperInstalled(isChinese: Bool) -> String {
        string("helper_installed", isChinese: isChinese, default: isChinese ? "特权辅助服务已就绪" : "Privileged helper installed")
    }

    public static func installHelperButton(isChinese: Bool) -> String {
        string("install_helper_button", isChinese: isChinese, default: isChinese ? "安装帮助程序…" : "Install Helper…")
    }

    public static func stagingDefaultFailure(isChinese: Bool) -> String {
        string("staging_default_failure", isChinese: isChinese, default: isChinese ? "正在自动完成初始化配置，这只需片刻。如果未自动恢复，请点击重试。" : "Finishing setup automatically — this only takes a moment. If it doesn't clear on its own, click Retry.")
    }

    public static func fdaRequiredTitle(isChinese: Bool) -> String {
        string("fda_required_title", isChinese: isChinese, default: isChinese ? "需要完全磁盘访问权限" : "Full Disk Access Required")
    }

    public static func fdaRequiredSubtitle(isChinese: Bool) -> String {
        string("fda_required_subtitle", isChinese: isChinese, default: isChinese ? "THLNTFS 需要权限以挂载和读取 NTFS 分区。" : "THLNTFS needs permission to mount and read NTFS drives.")
    }

    public static func fdaOpenSettings(isChinese: Bool) -> String {
        string("fda_open_settings", isChinese: isChinese, default: isChinese ? "打开系统设置" : "Open System Settings")
    }

    // MARK: - 菜单栏偏好设置项
    public static func launchAtLoginTitle(isChinese: Bool) -> String {
        string("launch_at_login", isChinese: isChinese, default: isChinese ? "开机自动启动" : "Launch at login")
    }

    public static func launchAtLoginDefaultSubtitle(isChinese: Bool) -> String {
        string("launch_at_login_subtitle", isChinese: isChinese, default: isChinese ? "登录系统时自动启动 THLNTFS 助手" : "Start THLNTFS helper automatically on login")
    }

    public static func reinstallHelperTitle(isChinese: Bool) -> String {
        string("reinstall_helper", isChinese: isChinese, default: isChinese ? "重新安装特权辅助服务" : "Reinstall privileged helper")
    }

    public static func reinstallHelperSubtitle(isChinese: Bool) -> String {
        string("reinstall_helper_subtitle", isChinese: isChinese, default: isChinese ? "修复 SMJobBless XPC 特权辅助守护进程" : "Repair the SMJobBless XPC helper")
    }

    public static func reinstallButton(isChinese: Bool) -> String {
        string("reinstall_button", isChinese: isChinese, default: isChinese ? "重新安装…" : "Reinstall…")
    }

    public static func uninstallTitle(isChinese: Bool) -> String {
        string("uninstall_title", isChinese: isChinese, default: isChinese ? "卸载 THLNTFS" : "Uninstall THLNTFS")
    }

    public static func uninstallSubtitleIdle(isChinese: Bool) -> String {
        string("uninstall_subtitle_idle", isChinese: isChinese, default: isChinese ? "移除命令行工具、后台依赖项与此特权服务 — 无任何残留" : "Remove the CLI, dependencies, and this helper — no leftovers")
    }

    public static func uninstallSubtitleRemovingDeps(isChinese: Bool) -> String {
        string("uninstall_subtitle_removing_deps", isChinese: isChinese, default: isChinese ? "正在移除后台依赖组件…" : "Removing CLI and dependencies…")
    }

    public static func uninstallSubtitleRemovingHelper(isChinese: Bool) -> String {
        string("uninstall_subtitle_removing_helper", isChinese: isChinese, default: isChinese ? "正在移除特权辅助服务…" : "Removing privileged helper…")
    }

    public static func uninstallSubtitleDone(isChinese: Bool) -> String {
        string("uninstall_subtitle_done", isChinese: isChinese, default: isChinese ? "已完全卸载。现在可以安全将 THLNTFS 移至废纸篓。" : "Uninstalled. Safe to drag THLNTFS to the Trash.")
    }

    public static func uninstallSubtitleFailed(reason: String, isChinese: Bool) -> String {
        let format = string("uninstall_subtitle_failed_format", isChinese: isChinese, default: isChinese ? "卸载失败: %@" : "Failed: %@")
        return String(format: format, reason)
    }

    public static func uninstallButton(isChinese: Bool) -> String {
        string("uninstall_button", isChinese: isChinese, default: isChinese ? "卸载…" : "Uninstall…")
    }

    public static func uninstallConfirmTitle(isChinese: Bool) -> String {
        string("uninstall_confirm_title", isChinese: isChinese, default: isChinese ? "确定要完全卸载 THLNTFS 吗？" : "Uninstall THLNTFS completely?")
    }

    public static func uninstallConfirmMessage(isChinese: Bool) -> String {
        string("uninstall_confirm_message", isChinese: isChinese, default: isChinese ? "此操作将完全移除命令行工具、所有内置依赖项与特权服务。完成后您可以将应用移至废纸篓。此操作无法撤销。" : "Removes the CLI, all vendored dependencies, and this privileged helper. Afterward, you can drag THLNTFS to the Trash. This can't be undone.")
    }

    public static func uninstallConfirmAction(isChinese: Bool) -> String {
        string("uninstall_confirm_action", isChinese: isChinese, default: isChinese ? "确认完全卸载" : "Uninstall Everything")
    }
}
