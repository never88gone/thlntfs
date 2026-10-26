import Foundation
import ServiceManagement
import HelperShared

public enum LaunchAtLoginRegistrationStatus: Equatable, Sendable {
    case disabled
    case enabled
    case requiresApproval
    case unavailable
}

public protocol LaunchAtLoginService: Sendable {
    func setEnabled(_ enabled: Bool) throws
}

public protocol LaunchAtLoginStatusProviding: LaunchAtLoginService {
    var status: LaunchAtLoginRegistrationStatus { get }
}

public struct RealLaunchAtLoginService: LaunchAtLoginStatusProviding {
    public init() {}

    public var status: LaunchAtLoginRegistrationStatus {
        switch SMAppService.mainApp.status {
        case .notRegistered:
            return .disabled
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .unavailable
        @unknown default:
            return .unavailable
        }
    }

    public func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}

private enum LaunchAtLoginUpdateResult: Sendable {
    case success(LaunchAtLoginRegistrationStatus)
    case failure(message: String, status: LaunchAtLoginRegistrationStatus)
}

/// 应用支持的界面显示语言 (跟随系统、英文、中文)
public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    /// 选项 1：跟随系统
    case system = "system"
    /// 选项 2：英文
    case english = "en"
    /// 选项 3：中文 (简体中文)
    case chinese = "zh-Hans"

    public var id: String { rawValue }

    public func localizedName(isChinese: Bool) -> String {
        switch self {
        case .system: return L10n.languageSystemName(isChinese: isChinese)
        case .english: return L10n.languageEnglishName(isChinese: isChinese)
        case .chinese: return L10n.languageChineseName(isChinese: isChinese)
        }
    }

    public var displayName: String {
        localizedName(isChinese: true)
    }
}

/// 偏好设置管理器，支持语言切换、开机启动、自动挂载新盘、通知开关与访达行为
@MainActor
public final class Settings: ObservableObject {
    @Published public var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: Keys.language)
            applyAppleLanguages(language)
        }
    }
    @Published public var launchAtLogin: Bool {
        didSet {
            guard !isApplyingLaunchAtLoginStatus else { return }
            beginLaunchAtLoginUpdate(launchAtLogin)
        }
    }
    @Published public var autoMountNewDrives: Bool {
        didSet { defaults.set(autoMountNewDrives, forKey: Keys.autoMountNewDrives) }
    }
    @Published public var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled) }
    }
    @Published public var openFinderOnMount: Bool {
        didSet { defaults.set(openFinderOnMount, forKey: Keys.openFinderOnMount) }
    }

    @Published public private(set) var isUpdatingLaunchAtLogin = false
    @Published public private(set) var launchAtLoginMessage: String?

    private let defaults: UserDefaults
    private let loginService: any LaunchAtLoginService
    private var confirmedLaunchAtLogin: Bool
    private var isApplyingLaunchAtLoginStatus = false

    public init(defaults: UserDefaults = .standard, loginService: any LaunchAtLoginService = RealLaunchAtLoginService()) {
        self.defaults = defaults
        self.loginService = loginService

        let persisted = defaults.object(forKey: Keys.launchAtLogin) as? Bool ?? Defaults.launchAtLogin
        let registrationStatus = Self.registrationStatus(for: loginService, fallbackEnabled: persisted)
        let initialValue = registrationStatus == .enabled

        launchAtLogin = initialValue
        confirmedLaunchAtLogin = initialValue
        launchAtLoginMessage = Self.message(for: registrationStatus)
        defaults.set(initialValue, forKey: Keys.launchAtLogin)

        self.autoMountNewDrives = defaults.object(forKey: Keys.autoMountNewDrives) as? Bool ?? true
        self.notificationsEnabled = defaults.object(forKey: Keys.notificationsEnabled) as? Bool ?? true
        self.openFinderOnMount = defaults.object(forKey: Keys.openFinderOnMount) as? Bool ?? true

        var persistedLang = defaults.string(forKey: Keys.language)
        if persistedLang == nil && defaults == .standard && Bundle.main.bundleIdentifier == nil {
            persistedLang = UserDefaults(suiteName: AppIdentifiers.mainAppBundleId)?.string(forKey: Keys.language)
        }
        if let raw = persistedLang, let lang = AppLanguage(rawValue: raw) {
            self.language = lang
        } else {
            self.language = Defaults.language
        }
        if self.language == .system {
            defaults.removeObject(forKey: "AppleLanguages")
        }
    }

    /// 严格检测 macOS 宿主系统当前首选语言是否为中文
    public static func detectSystemIsChinese() -> Bool {
        // 1. 检查 Locale.preferredLanguages 首位语言
        if let primary = Locale.preferredLanguages.first?.lowercased() {
            if primary.hasPrefix("zh") || primary.contains("chinese") {
                return true
            }
        }
        // 2. 检查当前 Locale 标识符 (如 zh_CN, zh-Hans-CN, zh_TW)
        let currentId = Locale.current.identifier.lowercased()
        if currentId.hasPrefix("zh") || currentId.contains("chinese") {
            return true
        }
        // 3. 检查语言代码 (如 zh)
        if let langCode = Locale.current.language.languageCode?.identifier.lowercased(),
           langCode.hasPrefix("zh") {
            return true
        }
        // 4. 兜底检查全局 defaults
        if let globalLangs = UserDefaults(suiteName: nil)?.stringArray(forKey: "AppleLanguages"),
           let firstGlobal = globalLangs.first?.lowercased(),
           firstGlobal.hasPrefix("zh") {
            return true
        }
        return false
    }

    /// 当前是否应呈现中文界面（跟随系统或者显式选择中文）
    public var isChinese: Bool {
        switch language {
        case .system:
            return Self.detectSystemIsChinese()
        case .english:
            return false
        case .chinese:
            return true
        }
    }

    /// 当前生效的 Locale
    public var effectiveLocale: Locale {
        isChinese ? Locale(identifier: "zh-Hans") : Locale(identifier: "en")
    }

    private func applyAppleLanguages(_ lang: AppLanguage) {
        switch lang {
        case .system:
            defaults.removeObject(forKey: "AppleLanguages")
        case .english:
            defaults.set(["en"], forKey: "AppleLanguages")
        case .chinese:
            defaults.set(["zh-Hans"], forKey: "AppleLanguages")
        }
    }

    public func setLaunchAtLogin(_ enabled: Bool) {
        guard !isUpdatingLaunchAtLogin else { return }
        setPublishedLaunchAtLogin(enabled)
        beginLaunchAtLoginUpdate(enabled)
    }

    public func refreshLaunchAtLoginStatus() {
        guard !isUpdatingLaunchAtLogin,
              let statusProvider = loginService as? any LaunchAtLoginStatusProviding else { return }
        applyLaunchAtLoginStatus(statusProvider.status)
    }

    private func beginLaunchAtLoginUpdate(_ enabled: Bool) {
        guard !isUpdatingLaunchAtLogin else {
            setPublishedLaunchAtLogin(confirmedLaunchAtLogin)
            return
        }
        guard enabled != confirmedLaunchAtLogin else {
            setPublishedLaunchAtLogin(confirmedLaunchAtLogin)
            return
        }

        if enabled,
           let statusProvider = loginService as? any LaunchAtLoginStatusProviding,
           statusProvider.status == .requiresApproval {
            applyLaunchAtLoginStatus(.requiresApproval)
            return
        }

        setPublishedLaunchAtLogin(enabled)
        launchAtLoginMessage = nil
        isUpdatingLaunchAtLogin = true

        let loginService = self.loginService
        let confirmedBeforeUpdate = confirmedLaunchAtLogin
        Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                do {
                    try loginService.setEnabled(enabled)
                    return LaunchAtLoginUpdateResult.success(
                        Self.registrationStatus(for: loginService, fallbackEnabled: enabled)
                    )
                } catch {
                    return LaunchAtLoginUpdateResult.failure(
                        message: error.localizedDescription,
                        status: Self.registrationStatus(
                            for: loginService,
                            fallbackEnabled: confirmedBeforeUpdate
                        )
                    )
                }
            }.value

            guard let self else { return }
            switch result {
            case .success(let status):
                self.applyLaunchAtLoginStatus(status)
            case .failure(let message, let status):
                self.applyLaunchAtLoginStatus(status, failureMessage: message)
            }
        }
    }

    private func applyLaunchAtLoginStatus(
        _ status: LaunchAtLoginRegistrationStatus,
        failureMessage: String? = nil
    ) {
        let enabled = status == .enabled
        confirmedLaunchAtLogin = enabled
        setPublishedLaunchAtLogin(enabled)
        launchAtLoginMessage = failureMessage.map { "Could not update Launch at login: \($0)" }
            ?? Self.message(for: status)
        isUpdatingLaunchAtLogin = false
        defaults.set(enabled, forKey: Keys.launchAtLogin)
    }

    private func setPublishedLaunchAtLogin(_ enabled: Bool) {
        isApplyingLaunchAtLoginStatus = true
        launchAtLogin = enabled
        isApplyingLaunchAtLoginStatus = false
    }

    private nonisolated static func registrationStatus(
        for service: any LaunchAtLoginService,
        fallbackEnabled: Bool
    ) -> LaunchAtLoginRegistrationStatus {
        if let statusProvider = service as? any LaunchAtLoginStatusProviding {
            return statusProvider.status
        }
        return fallbackEnabled ? .enabled : .disabled
    }

    private nonisolated static func message(
        for status: LaunchAtLoginRegistrationStatus
    ) -> String? {
        switch status {
        case .disabled, .enabled:
            return nil
        case .requiresApproval:
            return "Allow thlntfs in System Settings > General > Login Items."
        case .unavailable:
            return "Launch at login is unavailable for this app bundle."
        }
    }

    public enum Defaults {
        public static let language = AppLanguage.system
        public static let launchAtLogin = false
        public static let autoMountNewDrives = true
        public static let notificationsEnabled = true
        public static let openFinderOnMount = true
    }

    private enum Keys {
        static let language = "\(AppIdentifiers.settingsKeyPrefix).language"
        static let launchAtLogin = "\(AppIdentifiers.settingsKeyPrefix).launchAtLogin"
        static let autoMountNewDrives = "\(AppIdentifiers.settingsKeyPrefix).autoMountNewDrives"
        static let notificationsEnabled = "\(AppIdentifiers.settingsKeyPrefix).notificationsEnabled"
        static let openFinderOnMount = "\(AppIdentifiers.settingsKeyPrefix).openFinderOnMount"
    }
}
