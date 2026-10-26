import SwiftUI
import HelperShared

/// Shown whenever `CLIInstallChecker.isInstalled` is false — reuses `ui/prototype.html`'s
/// "Error — Helper Missing" visual language (comp lines 636-711: red triangle header, tinted
/// content box, primary action button, footer) for a sibling condition the comp doesn't
/// explicitly draw. This is always transient, self-fixing state, never a "go do something in
/// Terminal" dead end — `CLIAutoStager` already ran (or is about to, via `THLNTFSApp`'s
/// `.task(id: helperInstaller.state)`) the bundled `install.sh` as the already-root privileged
/// helper the moment it installed (`build/package-app.sh` bundles the full CLI/vendored tree into
/// `Contents/Resources/cli-src/` — nothing is staged separately, no tap, no Homebrew). If that
/// automatic attempt failed, the primary action retries the exact same in-app path
/// (`CLIAutoStager.retry()`) and surfaces why it failed — never a CLI/Terminal instruction, since
/// installing the helper is meant to set up the whole backend by itself.
public struct CLIMissingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale
    @Environment(\.openWindow) private var openWindow
    @ObservedObject public var checker: CLIInstallChecker
    @ObservedObject public var stager: CLIAutoStager
    public let onOpenSettings: () -> Void
    public let onQuit: () -> Void

    private var isChinese: Bool {
        locale.identifier.hasPrefix("zh")
    }

    private func openMainWindow() {
        MainWindowRegistry.shared.show()
        openWindow(id: "main-window")
        NotificationCenter.default.post(name: NSNotification.Name(AppIdentifiers.openMainWindowNotification), object: nil)
    }

    public init(
        checker: CLIInstallChecker,
        stager: CLIAutoStager,
        onOpenSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.checker = checker
        self.stager = stager
        self.onOpenSettings = onOpenSettings
        self.onQuit = onQuit
    }

    public init(checker: CLIInstallChecker, stager: CLIAutoStager, onQuit: @escaping () -> Void) {
        self.init(checker: checker, stager: stager, onOpenSettings: {}, onQuit: onQuit)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.ntfsRed.opacity(0.14))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.ntfsRed.opacity(0.28)))
                    ErrorTriangleGlyph(color: .ntfsRed)
                }
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 1) {
                    Text(L10n.appName(isChinese: isChinese)).font(.system(size: 13, weight: .semibold))
                    Text(L10n.setupRequired(isChinese: isChinese)).font(.system(size: 11)).foregroundStyle(Color.ntfsRed.opacity(0.75))
                }
                Spacer()
                Button(action: openMainWindow) {
                    Image(systemName: "macwindow")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(4)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help(L10n.openMainWindow(isChinese: isChinese))

                Circle().fill(Color.ntfsRed).frame(width: 9, height: 9)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                openMainWindow()
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)

            VStack(alignment: .leading, spacing: 5) {
                Text(L10n.setupIncomplete(isChinese: isChinese))
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Color.ntfsRed.opacity(0.95))
                Text(stager.lastFailureReason ?? L10n.stagingDefaultFailure(isChinese: isChinese))
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.ntfsRed.opacity(0.09)))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.ntfsRed.opacity(0.2)))
            .padding(.horizontal, 10)

            VStack(spacing: 6) {
                Button {
                    Task { await stager.retry() }
                } label: {
                    Text(L10n.retry(isChinese: isChinese)).frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassNeutral(colorScheme: colorScheme))
            }
            .padding(10)

            Divider().padding(.horizontal, 14)

            HStack(spacing: 5) {
                Button {
                    onOpenSettings()
                } label: {
                    SettingsGearGlyph(color: colorScheme == .dark ? .white.opacity(0.52) : .black.opacity(0.45))
                }
                .buttonStyle(.glassIcon(colorScheme: colorScheme))
                .accessibilityLabel(L10n.settings(isChinese: isChinese))
                .help(TooltipCopy.text(for: .settings))

                Button(action: openMainWindow) {
                    Image(systemName: "macwindow.on.rectangle")
                        .font(.system(size: 11))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.52) : .black.opacity(0.45))
                }
                .buttonStyle(.glassIcon(colorScheme: colorScheme))
                .accessibilityLabel(L10n.openMainWindow(isChinese: isChinese))
                .help(L10n.openMainWindow(isChinese: isChinese))

                Spacer()
                Button(L10n.quit(isChinese: isChinese), action: onQuit)
                    .buttonStyle(.glassFooter(colorScheme: colorScheme, foregroundOpacity: 0.42))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .frame(width: 300)
        .fixedSize(horizontal: false, vertical: true)
        // `stageIfNeeded()` is idempotent (guarded by `didAttempt`) — safe to call again here in
        // case this view renders before `THLNTFSApp`'s own `.task(id: helperInstaller.state)`
        // attempt has run or landed.
        .task {
            await stager.stageIfNeeded()
            checker.check()
        }
    }
}
