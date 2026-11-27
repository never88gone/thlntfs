import Foundation
import AppKit

/// GitHub Release Asset 数据模型
public struct GitHubReleaseAsset: Codable, Equatable, Sendable {
    public let name: String
    public let browserDownloadURL: URL
    public let size: Int64?

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
        case size
    }
}

/// GitHub Releases API `/releases/latest` 响应体
public struct GitHubReleasePayload: Codable, Equatable, Sendable {
    public let tagName: String
    public let name: String?
    public let body: String?
    public let htmlURL: URL
    public let publishedAt: String?
    public let draft: Bool?
    public let prerelease: Bool?
    public let assets: [GitHubReleaseAsset]?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlURL = "html_url"
        case publishedAt = "published_at"
        case draft
        case prerelease
        case assets
    }
}

/// 可用于界面展示的新版本升级信息
public struct ReleaseUpdateInfo: Equatable, Sendable, Identifiable {
    public var id: String { version }
    public let version: String
    public let tagName: String
    public let releaseNotes: String
    public let releasePageURL: URL
    public let dmgDownloadURL: URL?
    public let publishedAt: String?

    /// 优先返回 `.dmg` 直接下载链接，若未附带资产则回退至 Release 网页
    public var preferredDownloadURL: URL {
        dmgDownloadURL ?? releasePageURL
    }
}

/// 更新检查状态
public enum UpdateCheckState: Equatable, Sendable {
    case idle
    case checking
    case upToDate(version: String)
    case updateAvailable(ReleaseUpdateInfo)
    case failed(String)
}

/// 负责从 GitHub 仓库检查新版本并管理升级提醒流程的管理器
@MainActor
public final class UpdateChecker: ObservableObject {
    public static let defaultAPIURL = URL(string: "https://api.github.com/repos/never88gone/thlntfs/releases/latest")!
    public static let releasesPageURL = URL(string: "https://github.com/never88gone/thlntfs/releases")!

    @Published public private(set) var state: UpdateCheckState = .idle
    @Published public private(set) var lastCheckedAt: Date?
    @Published public var shouldShowBanner: Bool = false
    @Published public var isPresentingUpdateSheet: Bool = false

    public let currentVersion: String
    private let apiURL: URL
    private let defaults: UserDefaults
    private let minimumAutoCheckInterval: TimeInterval
    private var notifiedVersions: Set<String> = []

    private enum Keys {
        static let lastCheckTimestamp = "com.never88gone.thlntfs.update.lastCheckAt"
        static let skippedVersion = "com.never88gone.thlntfs.update.skippedVersion"
    }

    public init(
        currentVersion: String = ProductVersion.current().release,
        apiURL: URL = UpdateChecker.defaultAPIURL,
        defaults: UserDefaults = .standard,
        minimumAutoCheckInterval: TimeInterval = 6 * 3600
    ) {
        self.currentVersion = Self.normalizeVersionString(currentVersion)
        self.apiURL = apiURL
        self.defaults = defaults
        self.minimumAutoCheckInterval = minimumAutoCheckInterval
        if let ts = defaults.object(forKey: Keys.lastCheckTimestamp) as? Double, ts > 0 {
            self.lastCheckedAt = Date(timeIntervalSince1970: ts)
        }
    }

    public var availableUpdate: ReleaseUpdateInfo? {
        if case .updateAvailable(let info) = state { return info }
        return nil
    }

    public var skippedVersion: String? {
        defaults.string(forKey: Keys.skippedVersion)
    }

    /// 启动时静默检查（尊重自动检查开关与冷却时间，不弹出错误提示）
    public func checkInBackgroundIfNeeded(
        autoCheckEnabled: Bool,
        notificationManager: NotificationManager? = nil
    ) async {
        guard autoCheckEnabled else { return }
        if let last = lastCheckedAt, Date().timeIntervalSince(last) < minimumAutoCheckInterval {
            return
        }
        await checkForUpdates(userInitiated: false, notificationManager: notificationManager)
    }

    /// 执行一次 GitHub Release 版本检查
    public func checkForUpdates(
        userInitiated: Bool,
        notificationManager: NotificationManager? = nil
    ) async {
        if case .checking = state { return }

        let previousState = state
        state = .checking

        do {
            let payload = try await Self.fetchLatestRelease(from: apiURL, userAgentVersion: currentVersion)
            let now = Date()
            lastCheckedAt = now
            defaults.set(now.timeIntervalSince1970, forKey: Keys.lastCheckTimestamp)

            guard payload.draft != true, payload.prerelease != true else {
                state = .upToDate(version: currentVersion)
                shouldShowBanner = false
                return
            }

            let remoteVersion = Self.normalizeVersionString(payload.tagName)
            if Self.isRemoteVersion(remoteVersion, newerThan: currentVersion) {
                let dmgAsset = payload.assets?.first {
                    $0.name.lowercased().hasSuffix(".dmg")
                }
                let info = ReleaseUpdateInfo(
                    version: remoteVersion,
                    tagName: payload.tagName,
                    releaseNotes: (payload.body ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                    releasePageURL: payload.htmlURL,
                    dmgDownloadURL: dmgAsset?.browserDownloadURL,
                    publishedAt: payload.publishedAt
                )
                state = .updateAvailable(info)

                let isSkipped = (skippedVersion == remoteVersion)
                if userInitiated {
                    // 用户主动检查时忽略历史跳过标记并直接弹窗展示升级信息
                    shouldShowBanner = true
                    isPresentingUpdateSheet = true
                } else if !isSkipped {
                    shouldShowBanner = true
                    if !notifiedVersions.contains(remoteVersion) {
                        notifiedVersions.insert(remoteVersion)
                        notificationManager?.postUpdateAvailable(version: remoteVersion)
                    }
                }
            } else {
                state = .upToDate(version: currentVersion)
                shouldShowBanner = false
            }
        } catch {
            if userInitiated {
                state = .failed(error.localizedDescription)
            } else {
                // 静默后台检查失败不打扰用户
                state = previousState == .checking ? .idle : previousState
            }
        }
    }

    /// 跳过特定版本的提醒
    public func skipVersion(_ version: String) {
        defaults.set(Self.normalizeVersionString(version), forKey: Keys.skippedVersion)
        shouldShowBanner = false
        isPresentingUpdateSheet = false
    }

    /// 本次运行暂不展示横幅（可在偏好设置随时重新打开升级弹窗）
    public func dismissBannerForNow() {
        shouldShowBanner = false
    }

    /// 清除跳过版本标记并打开更新弹窗
    public func presentUpdateDetails() {
        guard availableUpdate != nil else { return }
        isPresentingUpdateSheet = true
    }

    /// 调起浏览器下载最新 DMG（或前往 Release 页）
    public func openPreferredDownload() {
        let targetURL = availableUpdate?.preferredDownloadURL ?? Self.releasesPageURL
        NSWorkspace.shared.open(targetURL)
    }

    /// 调起浏览器查看 GitHub Release 页面
    public func openReleasePage() {
        let targetURL = availableUpdate?.releasePageURL ?? Self.releasesPageURL
        NSWorkspace.shared.open(targetURL)
    }

    // MARK: - 网络请求与版本比较 (nonisolated)

    private nonisolated static func fetchLatestRelease(
        from url: URL,
        userAgentVersion: String
    ) async throws -> GitHubReleasePayload {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("THLNTFS/\(userAgentVersion)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw NSError(
                domain: "THLNTFSUpdateChecker",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "GitHub API HTTP \(httpResponse.statusCode)"]
            )
        }
        return try JSONDecoder().decode(GitHubReleasePayload.self, from: data)
    }

    public nonisolated static func normalizeVersionString(_ raw: String) -> String {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("v") || trimmed.hasPrefix("V") {
            trimmed.removeFirst()
        }
        if let plusIndex = trimmed.firstIndex(of: "+") {
            trimmed = String(trimmed[..<plusIndex])
        }
        return trimmed
    }

    /// 比较语义化版本号，判断 `remote` 是否严格大于 `local`
    public nonisolated static func isRemoteVersion(_ remote: String, newerThan local: String) -> Bool {
        let rParts = splitSemver(normalizeVersionString(remote))
        let lParts = splitSemver(normalizeVersionString(local))
        guard !rParts.numbers.isEmpty, !lParts.numbers.isEmpty else { return false }

        let count = max(rParts.numbers.count, lParts.numbers.count)
        for idx in 0..<count {
            let rv = idx < rParts.numbers.count ? rParts.numbers[idx] : 0
            let lv = idx < lParts.numbers.count ? lParts.numbers[idx] : 0
            if rv != lv { return rv > lv }
        }

        // 数字段完全相等：正式版 (prerelease == nil) > 预发布版
        switch (rParts.prerelease, lParts.prerelease) {
        case (nil, nil): return false
        case (nil, .some): return true
        case (.some, nil): return false
        case (.some(let rp), .some(let lp)):
            return rp.compare(lp, options: [.numeric]) == .orderedDescending
        }
    }

    private nonisolated static func splitSemver(_ version: String) -> (numbers: [Int], prerelease: String?) {
        let components = version.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let core = String(components[0])
        let prerelease = components.count > 1 ? String(components[1]) : nil
        let nums = core.split(separator: ".").compactMap { Int($0) }
        // 若存在非数字版本段则拒绝误判升级
        guard nums.count == core.split(separator: ".").count else { return ([], prerelease) }
        return (nums, prerelease)
    }
}
