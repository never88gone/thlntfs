import SwiftUI
import AppKit
import HelperShared

/// "Other available devices" section copy — the unmounted-drives list shown below the mounted
/// list when one or more drives are already mounted.
public enum OtherAvailableCopy {
    public static let label = "Other available devices"
}

/// Pure gating decision for the "Other available devices" section, extracted from the view so the
/// idle-vs-mounted behavior is testable without rendering an image.
public enum OtherAvailableSection {
    public static func shouldRender(isMounted: Bool) -> Bool { isMounted }
    public static func rowsRender(availableCount: Int) -> Bool { availableCount > 0 }
}

public struct PopoverContentView: View {
    @ObservedObject public var appState: AppState
    @ObservedObject public var driveScanner: DriveScanner
    @ObservedObject public var mountController: MountController
    @ObservedObject public var throughputMonitor: ThroughputMonitor
    @ObservedObject public var remountController: RemountController
    @ObservedObject public var diagnoseRunner: DiagnoseRunner
    @ObservedObject public var helperInstaller: HelperInstaller
    @ObservedObject public var helperUninstaller: HelperUninstaller
    @ObservedObject public var cliInstallChecker: CLIInstallChecker
    @ObservedObject public var cliAutoStager: CLIAutoStager
    @ObservedObject public var settings: Settings
    @StateObject private var navigation: PopoverNavigation
    public let finderOpener: FinderOpener
    public let helperClient: HelperClient

    @Environment(\.colorScheme) private var colorScheme
    @State private var diagnosePresentation = DiagnosePanelPresentation()
    @State private var securityPresentation = SecurityIndicatorsPresentation()
    @State private var showFDAPrompt = false

    public init(
        appState: AppState,
        driveScanner: DriveScanner,
        mountController: MountController,
        throughputMonitor: ThroughputMonitor,
        remountController: RemountController,
        diagnoseRunner: DiagnoseRunner,
        helperInstaller: HelperInstaller,
        helperUninstaller: HelperUninstaller,
        cliInstallChecker: CLIInstallChecker,
        cliAutoStager: CLIAutoStager,
        settings: Settings,
        finderOpener: FinderOpener,
        helperClient: HelperClient,
        navigation: PopoverNavigation
    ) {
        self.appState = appState
        self.driveScanner = driveScanner
        self.mountController = mountController
        self.throughputMonitor = throughputMonitor
        self.remountController = remountController
        self.diagnoseRunner = diagnoseRunner
        self.helperInstaller = helperInstaller
        self.helperUninstaller = helperUninstaller
        self.cliInstallChecker = cliInstallChecker
        self.cliAutoStager = cliAutoStager
        self.settings = settings
        self.finderOpener = finderOpener
        self.helperClient = helperClient
        _navigation = StateObject(wrappedValue: navigation)
    }

    public init(
        appState: AppState,
        driveScanner: DriveScanner,
        mountController: MountController,
        throughputMonitor: ThroughputMonitor,
        remountController: RemountController,
        diagnoseRunner: DiagnoseRunner,
        helperInstaller: HelperInstaller,
        cliInstallChecker: CLIInstallChecker,
        cliAutoStager: CLIAutoStager,
        settings: Settings,
        finderOpener: FinderOpener,
        helperClient: HelperClient
    ) {
        self.init(
            appState: appState,
            driveScanner: driveScanner,
            mountController: mountController,
            throughputMonitor: throughputMonitor,
            remountController: remountController,
            diagnoseRunner: diagnoseRunner,
            helperInstaller: helperInstaller,
            helperUninstaller: HelperUninstaller(),
            cliInstallChecker: cliInstallChecker,
            cliAutoStager: cliAutoStager,
            settings: settings,
            finderOpener: finderOpener,
            helperClient: helperClient,
            navigation: PopoverNavigation()
        )
    }

    public var body: some View {
        Group {
            if navigation.page == .settings {
                PreferencesView(
                    settings: settings,
                    installer: helperInstaller,
                    uninstaller: helperUninstaller,
                    onBack: navigation.showMain
                )
            } else if showFDAPrompt {
                FDAPromptView(
                    onOpenSettings: {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                            NSWorkspace.shared.open(url)
                        }
                        showFDAPrompt = false
                        mountController.clearError()
                    },
                    onCancel: {
                        showFDAPrompt = false
                        mountController.clearError()
                    }
                )
            } else if helperInstaller.state != .installed {
                FirstRunView(
                    installer: helperInstaller,
                    diagnoseRunner: diagnoseRunner,
                    onOpenSettings: navigation.showSettings,
                    onQuit: quit
                )
            } else if !cliInstallChecker.isInstalled {
                CLIMissingView(
                    checker: cliInstallChecker,
                    stager: cliAutoStager,
                    onOpenSettings: navigation.showSettings,
                    onQuit: quit
                )
            } else {
                mainContent
            }
        }
        .onChange(of: mountController.errorMessage) { newValue in
            if newValue == "FDA_REQUIRED" {
                showFDAPrompt = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .thlntfsOpenSettings)) { _ in
            navigation.showSettings()
        }
        .task {
            await refreshAll()
        }
    }

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            PopoverHeaderView(
                appState: appState,
                driveScanner: driveScanner,
                settings: settings,
                onOpenMainWindow: openMainWindow
            )

            if let mounted = mountController.mountedDrive {
                DirtyBannerView(appState: appState, remountController: remountController, drive: mounted)
            }

            Divider()

            if !mountController.mountedDrives.isEmpty {
                ForEach(mountController.mountedDrives) { entry in
                    DriveRow(
                        drive: entry.drive,
                        isMounted: true,
                        isDirty: entry.isDirty,
                        onUnmount: { Task { await mountController.unmount(driveID: entry.id) } },
                        onMountAnyway: { remountController.requestRemount() }
                    )
                }
            }

            if mountController.mountedDrives.isEmpty && !driveScanner.drives.isEmpty {
                HStack(spacing: 6) {
                    Spacer()
                    Button {
                        Task { await refreshAll() }
                    } label: {
                        HStack(spacing: 6) {
                            RefreshGlyph()
                            Text(L10n.tr("refresh", isChinese: settings.isChinese))
                        }
                    }
                    .buttonStyle(.glassNeutral(colorScheme: colorScheme))
                }
                ForEach(driveScanner.drives) { drive in
                    DriveRow(
                        drive: drive,
                        isMounted: false,
                        onMount: { mountDrive(drive) }
                    )
                }
            }

            if OtherAvailableSection.shouldRender(isMounted: !mountController.mountedDrives.isEmpty) {
                Divider()
                HStack(spacing: 6) {
                    Text(L10n.tr("other_available_devices", isChinese: settings.isChinese))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        Task { await refreshAll() }
                    } label: {
                        RefreshGlyph()
                    }
                    .buttonStyle(.glassIcon(colorScheme: colorScheme))
                }
                if OtherAvailableSection.rowsRender(availableCount: otherAvailableDrives.count) {
                    ForEach(otherAvailableDrives) { drive in
                        DriveRow(
                            drive: drive,
                            isMounted: false,
                            onMount: { mountDrive(drive) }
                        )
                    }
                }
            }

            if mountController.mountedDrives.isEmpty && driveScanner.drives.isEmpty {
                PopoverEmptyStateView(onRefresh: {
                    Task { await refreshAll() }
                })
            }

            if !mountController.mountedDrives.isEmpty {
                Divider()
                if securityPresentation.isVisible {
                    SecurityIndicatorsView(
                        isolatedNetwork: .unknown,
                        vpnBypass: .unknown,
                        onHide: { securityPresentation.hide() }
                    )
                } else {
                    HiddenSecurityIndicatorsView {
                        securityPresentation.show()
                    }
                }
            }

            if let errorMessage = mountController.errorMessage ?? remountController.errorMessage, errorMessage != "FDA_REQUIRED" {
                Text(errorMessage).font(.caption).foregroundStyle(Color.ntfsRed)
            }

            if let warning = mountController.reconciliationWarning {
                Text(warning).font(.caption).foregroundStyle(Color.ntfsYellow)
            }

            if diagnosePresentation.isVisible {
                DiagnosePanel(runner: diagnoseRunner, mountState: appState.state) {
                    diagnosePresentation.hide()
                }
            }

            Divider()

            PopoverFooterView(
                diagnoseRunner: diagnoseRunner,
                settings: settings,
                diagnosePresentationVisible: Binding(
                    get: { diagnosePresentation.isVisible },
                    set: { if $0 { diagnosePresentation.show() } else { diagnosePresentation.hide() } }
                ),
                onOpenSettings: navigation.showSettings,
                onOpenMainWindow: openMainWindow,
                onQuit: quit
            )
        }
        .padding(12)
        .frame(width: 320)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var otherAvailableDrives: [Drive] {
        driveScanner.drives.filter { !mountController.mountedDriveIDs.contains($0.id) }
    }

    private func mountDrive(_ drive: Drive) {
        Task { await mountController.mount(drive, mountPoint: nil, readOnly: false) }
    }

    private func refreshAll() async {
        await driveScanner.refresh()
        await mountController.reconcile(knownDrives: driveScanner.drives)
    }

    private func openMainWindow() {
        NotificationCenter.default.post(name: .thlntfsOpenMainWindow, object: nil)
        MainWindowRegistry.shared.show()
    }

    private func quit() {
        Task {
            await mountController.unmount()
            _ = try? await helperClient.teardown()
            _ = try? await helperClient.exitHelper()
            NSApp.terminate(nil)
        }
    }
}
