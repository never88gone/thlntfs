import SwiftUI

/// MenuBarExtra uses a transient window. A native `confirmationDialog` dismisses that window as
/// its destructive button is selected, which made the uninstall action appear to vanish before
/// it reliably reached `HelperUninstaller`. Keep confirmation state in the popover itself instead.
public struct UninstallConfirmationPresentation: Equatable, Sendable {
    public private(set) var isVisible: Bool

    public init(isVisible: Bool = false) {
        self.isVisible = isVisible
    }

    public mutating func request() { isVisible = true }
    public mutating func cancel() { isVisible = false }

    /// Consumes one explicit confirmation. A stale/double action cannot start two uninstalls.
    public mutating func confirm() -> Bool {
        guard isVisible else { return false }
        isVisible = false
        return true
    }
}

/// GUI-PLAN.md "Settings page" table, using the same controls and application-owned state as the
/// former Preferences window. "Reinstall privileged helper" reuses `HelperInstaller.install()`
/// directly — the same path `3-first-run-install` built for first-run, per that unit's Do clause.
public struct PreferencesView: View {
    @ObservedObject public var settings: Settings
    @ObservedObject public var installer: HelperInstaller
    @ObservedObject public var uninstaller: HelperUninstaller
    public let onBack: (() -> Void)?
    public let productVersion: ProductVersion

    @Environment(\.colorScheme) private var colorScheme
    @State private var uninstallConfirmation: UninstallConfirmationPresentation

    public init(
        settings: Settings,
        installer: HelperInstaller,
        uninstaller: HelperUninstaller,
        onBack: (() -> Void)?
    ) {
        self.init(
            settings: settings,
            installer: installer,
            uninstaller: uninstaller,
            onBack: onBack,
            productVersion: .current(),
            uninstallConfirmation: .init()
        )
    }

    public init(
        settings: Settings,
        installer: HelperInstaller,
        uninstaller: HelperUninstaller,
        onBack: (() -> Void)?,
        productVersion: ProductVersion
    ) {
        self.init(
            settings: settings,
            installer: installer,
            uninstaller: uninstaller,
            onBack: onBack,
            productVersion: productVersion,
            uninstallConfirmation: .init()
        )
    }

    init(
        settings: Settings,
        installer: HelperInstaller,
        uninstaller: HelperUninstaller,
        onBack: (() -> Void)?,
        productVersion: ProductVersion,
        uninstallConfirmation: UninstallConfirmationPresentation
    ) {
        self.settings = settings
        self.installer = installer
        self.uninstaller = uninstaller
        self.onBack = onBack
        self.productVersion = productVersion
        _uninstallConfirmation = State(initialValue: uninstallConfirmation)
    }

    /// Source-compatible initializer for existing embeddings. The production app always supplies
    /// `onBack` and presents this view inside the menu-bar popover.
    public init(settings: Settings, installer: HelperInstaller, uninstaller: HelperUninstaller) {
        self.init(settings: settings, installer: installer, uninstaller: uninstaller, onBack: nil)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let onBack {
                // ZStack so "Settings" centers over the full popover width — an HStack with two
                // Spacers would center it in the *remaining* space after the Back button, sitting
                // right-of-true-center. The title is the visual anchor; Back is overlaid leading.
                ZStack {
                    VStack(spacing: 1) {
                        Text(L10n.settings(isChinese: settings.isChinese))
                            .font(.system(size: 13, weight: .semibold))
                        Text(productVersion.settingsText)
                            .font(.system(size: 9, weight: .regular))
                            .foregroundStyle(.secondary.opacity(0.72))
                            .accessibilityLabel("\(L10n.appName(isChinese: settings.isChinese)) \(productVersion.settingsText)")
                    }
                    HStack {
                        Button {
                            onBack()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text(L10n.back(isChinese: settings.isChinese))
                            }
                        }
                        .buttonStyle(.glassNeutral(colorScheme: colorScheme))
                        .accessibilityLabel("Back")
                        .help(TooltipCopy.text(for: .back))
                        Spacer()
                    }
                }
                Divider()
            }

            row(L10n.languageTitle(isChinese: settings.isChinese), L10n.languageSubtitle(isChinese: settings.isChinese)) {
                Picker("", selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.localizedName(isChinese: settings.isChinese)).tag(lang)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 140)
                .accessibilityIdentifier("菜单栏语言选择")
            }

            Divider()

            row(L10n.launchAtLoginTitle(isChinese: settings.isChinese), launchAtLoginSubtitle) {
                HStack(spacing: 8) {
                    if settings.isUpdatingLaunchAtLogin {
                        ProgressView().controlSize(.small)
                    }
                    Toggle(
                        L10n.launchAtLoginTitle(isChinese: settings.isChinese),
                        isOn: Binding(
                            get: { settings.launchAtLogin },
                            set: { settings.setLaunchAtLogin($0) }
                        )
                    )
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .disabled(settings.isUpdatingLaunchAtLogin)
                    .accessibilityLabel("Launch at login")
                }
            }

            Divider()

            row(L10n.reinstallHelperTitle(isChinese: settings.isChinese), L10n.reinstallHelperSubtitle(isChinese: settings.isChinese)) {
                HStack(spacing: 6) {
                    if installer.state == .installing {
                        ProgressView().controlSize(.small)
                    }
                    Button(L10n.reinstallButton(isChinese: settings.isChinese)) {
                        Task { await installer.install() }
                    }
                }
            }

            row(L10n.uninstallTitle(isChinese: settings.isChinese), uninstallSubtitle) {
                HStack(spacing: 6) {
                    if uninstaller.state == .removingDependencies || uninstaller.state == .removingHelper {
                        ProgressView().controlSize(.small)
                    }
                    Button(L10n.uninstallButton(isChinese: settings.isChinese), role: .destructive) {
                        uninstallConfirmation.request()
                    }
                    .disabled(
                        uninstaller.state == .removingDependencies
                            || uninstaller.state == .removingHelper
                            || isUninstallComplete
                    )
                }
            }

            if uninstallConfirmation.isVisible {
                inlineUninstallConfirmation
            }
        }
        .padding(16)
        .frame(width: 320)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { settings.refreshLaunchAtLoginStatus() }
    }

    private var uninstallSubtitle: String {
        let isZh = settings.isChinese
        switch uninstaller.state {
        case .idle:
            return L10n.uninstallSubtitleIdle(isChinese: isZh)
        case .removingDependencies:
            return L10n.uninstallSubtitleRemovingDeps(isChinese: isZh)
        case .removingHelper:
            return L10n.uninstallSubtitleRemovingHelper(isChinese: isZh)
        case .done:
            return L10n.uninstallSubtitleDone(isChinese: isZh)
        case .failed(let message):
            return L10n.uninstallSubtitleFailed(reason: message, isChinese: isZh)
        }
    }

    private var launchAtLoginSubtitle: String {
        settings.launchAtLoginMessage ?? L10n.launchAtLoginDefaultSubtitle(isChinese: settings.isChinese)
    }

    /// Inline (in-popover) two-step confirmation — a native `confirmationDialog` would dismiss
    /// MenuBarExtra's transient window before the destructive action reliably reached the helper
    /// (per PR #10). `uninstallConfirmation.confirm()` consumes one explicit tap so a stale/double
    /// action can never start two uninstalls.
    private var inlineUninstallConfirmation: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.uninstallConfirmTitle(isChinese: settings.isChinese))
                .font(.system(size: 13, weight: .semibold))
            Text(L10n.uninstallConfirmMessage(isChinese: settings.isChinese))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Spacer()
                Button(L10n.cancel(isChinese: settings.isChinese)) {
                    uninstallConfirmation.cancel()
                }
                .buttonStyle(.glassNeutral(colorScheme: colorScheme))

                Button(L10n.uninstallConfirmAction(isChinese: settings.isChinese), role: .destructive) {
                    guard uninstallConfirmation.confirm() else { return }
                    Task { await uninstaller.uninstallEverything() }
                }
                .buttonStyle(.glassDestructive(colorScheme: colorScheme))
            }
        }
        .glassCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Confirm complete thlntfs uninstall")
    }

    private var isUninstallComplete: Bool {
        if case .done = uninstaller.state { return true }
        return false
    }

    @ViewBuilder
    private func row<Control: View>(
        _ title: String, _ subtitle: String, @ViewBuilder control: () -> Control
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            control()
        }
        .glassCard()
    }

}
