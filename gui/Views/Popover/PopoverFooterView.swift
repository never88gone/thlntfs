import SwiftUI
import AppKit
import HelperShared

/// 菜单栏卡片底部工具栏
public struct PopoverFooterView: View {
    @ObservedObject public var diagnoseRunner: DiagnoseRunner
    @ObservedObject public var settings: Settings
    public let onOpenSettings: () -> Void
    public let onOpenMainWindow: () -> Void
    public let onQuit: () -> Void
    @Binding public var diagnosePresentationVisible: Bool

    @Environment(\.colorScheme) private var colorScheme

    public init(
        diagnoseRunner: DiagnoseRunner,
        settings: Settings,
        diagnosePresentationVisible: Binding<Bool>,
        onOpenSettings: @escaping () -> Void,
        onOpenMainWindow: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.diagnoseRunner = diagnoseRunner
        self.settings = settings
        self._diagnosePresentationVisible = diagnosePresentationVisible
        self.onOpenSettings = onOpenSettings
        self.onOpenMainWindow = onOpenMainWindow
        self.onQuit = onQuit
    }

    public var body: some View {
        HStack(spacing: 5) {
            Button(action: onOpenMainWindow) {
                Image(systemName: "macwindow.on.rectangle")
            }
            .buttonStyle(.glassIcon(colorScheme: colorScheme))
            .accessibilityLabel(L10n.tr("open_main_window", isChinese: settings.isChinese))
            .help(L10n.openMainWindow(isChinese: settings.isChinese))

            Button(action: onOpenSettings) {
                SettingsGearGlyph(color: .secondary)
            }
            .buttonStyle(.glassIcon(colorScheme: colorScheme))
            .accessibilityLabel(L10n.tr("settings", isChinese: settings.isChinese))
            .help(TooltipCopy.text(for: .settings))

            Button {
                let mode = DiagnoseActionMode.resolve(
                    commandPressed: NSEvent.modifierFlags.contains(.command)
                )
                diagnosePresentationVisible = true
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
                    Text(L10n.tr("diagnose", isChinese: settings.isChinese))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 28)
            }
            .buttonStyle(.glassFooter(colorScheme: colorScheme))
            .disabled(diagnoseRunner.isRunning)
            .help(TooltipCopy.text(for: .diagnose))

            Button(action: onQuit) {
                Text(L10n.tr("quit", isChinese: settings.isChinese)).frame(height: 28)
            }
            .buttonStyle(.glassFooter(colorScheme: colorScheme))
            .help(TooltipCopy.text(for: .quit))
        }
    }
}
