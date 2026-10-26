import SwiftUI
import AppKit
import HelperShared

/// First-run helper-install prompt (GUI-PLAN.md "App shape": "No windows except Preferences and
/// the first-run helper prompt"). Kicks off `installIfNeeded()` on appear; denial/failure renders
/// `ui/prototype.html`'s "Error — Helper Missing" card (comp lines 636-711) — red icon-box header,
/// message card, primary "Install Helper…" pill, and a footer so Quit/Settings stay reachable even
/// before the helper exists (previously this view had no footer at all — a real dead end).
/// ponytail: the comp's card also shows a separate "Retry" button next to "Diagnose", but this
/// app's `HelperInstaller` only exposes one unconditional `install()` path (Do clause: same path
/// Preferences' "Reinstall…" uses) — a second button calling the identical action would be a fake
/// distinction, so "Install Helper…" is the only action button; "Diagnose" is the other.
public struct FirstRunView: View {
    @ObservedObject public var installer: HelperInstaller
    @ObservedObject public var diagnoseRunner: DiagnoseRunner
    public let onOpenSettings: () -> Void
    public let onQuit: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale
    @Environment(\.openWindow) private var openWindow
    @State private var diagnosePresentation = DiagnosePanelPresentation()

    private var isChinese: Bool {
        locale.identifier.hasPrefix("zh")
    }

    private func openMainWindow() {
        MainWindowRegistry.shared.show()
        openWindow(id: "main-window")
        NotificationCenter.default.post(name: NSNotification.Name(AppIdentifiers.openMainWindowNotification), object: nil)
    }

    public init(
        installer: HelperInstaller,
        diagnoseRunner: DiagnoseRunner,
        onOpenSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.installer = installer
        self.diagnoseRunner = diagnoseRunner
        self.onOpenSettings = onOpenSettings
        self.onQuit = onQuit
    }

    public init(installer: HelperInstaller, diagnoseRunner: DiagnoseRunner, onQuit: @escaping () -> Void) {
        self.init(installer: installer, diagnoseRunner: diagnoseRunner, onOpenSettings: {}, onQuit: onQuit)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            switch installer.state {
            case .notChecked, .checking:
                ProgressView(L10n.checkingHelper(isChinese: isChinese))
                    .frame(maxWidth: .infinity)
            case .installing:
                ProgressView(L10n.waitingForAuth(isChinese: isChinese))
                    .frame(maxWidth: .infinity)
            case .installed:
                Label(L10n.helperInstalled(isChinese: isChinese), systemImage: "checkmark.seal.fill")
                    .foregroundStyle(Color.ntfsGreen)
            case .denied(let message), .failed(let message):
                errorCard(message: message)
                Button {
                    Task { await installer.install() }
                } label: {
                    HStack(spacing: 6) {
                        InstallHelperGlyph()
                        Text(L10n.installHelperButton(isChinese: isChinese))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassPrimary())

                Button {
                    let mode = DiagnoseActionMode.resolve(
                        commandPressed: NSEvent.modifierFlags.contains(.command)
                    )
                    diagnosePresentation.show()
                    Task {
                        switch mode {
                        case .summary:
                            await diagnoseRunner.run()
                        case .developerJSONExport:
                            if let document = await diagnoseRunner.runForDeveloperExport() {
                                DeveloperDiagnoseSavePanel.present(document: document)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        DiagnoseGlyph()
                        Text(L10n.diagnose(isChinese: isChinese))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassNeutral(colorScheme: colorScheme))
                .disabled(diagnoseRunner.isRunning)
                .help(TooltipCopy.text(for: .diagnose))
            }

            if diagnosePresentation.isVisible {
                DiagnosePanel(runner: diagnoseRunner) {
                    diagnosePresentation.hide()
                }
            }

            Divider()
            footer
        }
        .padding(12)
        .frame(width: 300)
        .fixedSize(horizontal: false, vertical: true)
        .task {
            await installer.installIfNeeded()
        }
    }

    private var header: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(headerColor.opacity(0.14))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(headerColor.opacity(0.28)))
                ErrorTriangleGlyph(color: headerColor)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(L10n.appName()).font(.system(size: 13, weight: .semibold))
                Text(headerSubtitle).font(.system(size: 11)).foregroundStyle(headerColor.opacity(0.75))
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

            Circle().fill(headerColor).frame(width: 9, height: 9)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            openMainWindow()
        }
    }

    private var headerColor: Color {
        switch installer.state {
        case .denied, .failed: .ntfsRed
        case .installed: .ntfsGreen
        case .notChecked, .checking, .installing: .secondary
        }
    }

    private var headerSubtitle: String {
        switch installer.state {
        case .denied, .failed: L10n.setupRequired(isChinese: isChinese)
        case .installed: L10n.helperInstalled(isChinese: isChinese)
        case .notChecked, .checking: L10n.checkingHelper(isChinese: isChinese)
        case .installing: L10n.waitingForAuth(isChinese: isChinese)
        }
    }

    private func errorCard(message: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(L10n.tr("helper_not_installed", isChinese: isChinese))
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Color.ntfsRed.opacity(0.95))
            Text(message)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.ntfsRed.opacity(0.09)))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.ntfsRed.opacity(0.2)))
    }

    private var footer: some View {
        HStack {
            Button {
                onOpenSettings()
            } label: {
                SettingsGearGlyph(color: .secondary)
            }
            .buttonStyle(.glassIcon(colorScheme: colorScheme))
            .accessibilityLabel(L10n.settings(isChinese: isChinese))
            .help(TooltipCopy.text(for: .settings))

            Button(action: openMainWindow) {
                Image(systemName: "macwindow.on.rectangle")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.glassIcon(colorScheme: colorScheme))
            .accessibilityLabel(L10n.openMainWindow(isChinese: isChinese))
            .help(L10n.openMainWindow(isChinese: isChinese))

            Spacer()
            Button(action: onQuit) {
                Text(L10n.quit(isChinese: isChinese)).frame(height: 28)
            }
            .buttonStyle(.glassFooter(colorScheme: colorScheme))
            .help(TooltipCopy.text(for: .quit))
        }
    }
}
