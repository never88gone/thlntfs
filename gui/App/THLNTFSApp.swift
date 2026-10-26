import AppKit
import THLNTFSGUI
import SwiftUI
import os.log
import HelperShared

private let lifecycleLog = Logger(subsystem: AppIdentifiers.mainAppBundleId, category: "Lifecycle")

final class THLNTFSApplicationDelegate: NSObject, NSApplicationDelegate {
    private var singleInstanceGuard: SingleInstanceGuard?

    func applicationWillFinishLaunching(_ notification: Notification) {
        do {
            singleInstanceGuard = try SingleInstanceGuard()
        } catch SingleInstanceGuardError.alreadyRunning {
            lifecycleLog.notice("A second GUI instance was blocked")
            NSApplication.shared.terminate(nil)
        } catch {
            lifecycleLog.error(
                "Unable to acquire the GUI instance lock: \(error.localizedDescription, privacy: .public)"
            )
            NSApplication.shared.terminate(nil)
        }
    }
}

/// 支持独立主管理窗口与菜单栏常驻助手的多场景应用程序主入口
@main
struct THLNTFSApp: App {
    @NSApplicationDelegateAdaptor(THLNTFSApplicationDelegate.self) private var applicationDelegate
    @StateObject private var appState: AppState
    @StateObject private var driveScanner: DriveScanner
    @StateObject private var mountController: MountController
    @StateObject private var throughputMonitor: ThroughputMonitor
    @StateObject private var remountController: RemountController
    @StateObject private var diagnoseRunner = DiagnoseRunner()
    @StateObject private var helperInstaller: HelperInstaller
    @StateObject private var helperUninstaller: HelperUninstaller
    @StateObject private var cliInstallChecker: CLIInstallChecker
    @StateObject private var settings = Settings()
    @StateObject private var navigation = PopoverNavigation()
    @StateObject private var diskOpController = DiskOperationController()
    @StateObject private var startupManager = StartupDiskManager()
    @StateObject private var autoMountManager = AutoMountManager()
    @StateObject private var notificationManager = NotificationManager()

    private let finderOpener = FinderOpener()
    private let helperClient = HelperClient()
    @StateObject private var cliAutoStager: CLIAutoStager

    init() {
        let appState = AppState()
        _appState = StateObject(wrappedValue: appState)

        if let demoMode = ProcessInfo.processInfo.environment["THLNTFS_UI_DEMO"] {
            _driveScanner = StateObject(wrappedValue: DemoScaffold.driveScanner())
            _mountController = StateObject(wrappedValue: DemoScaffold.mountController(mode: demoMode, appState: appState))
            _remountController = StateObject(wrappedValue: DemoScaffold.remountController(appState: appState))
            _throughputMonitor = StateObject(wrappedValue: DemoScaffold.throughputMonitor())
        } else {
            _driveScanner = StateObject(wrappedValue: DriveScanner())
            _mountController = StateObject(wrappedValue: MountController(appState: appState))
            _remountController = StateObject(wrappedValue: RemountController(appState: appState))
            _throughputMonitor = StateObject(wrappedValue: ThroughputMonitor())
        }

        let helperInstaller: HelperInstaller
        if let installOutcome = ProcessInfo.processInfo.environment["THLNTFS_INSTALL_DEMO"] {
            helperInstaller = DemoScaffold.helperInstaller(outcome: installOutcome)
        } else {
            helperInstaller = HelperInstaller()
        }
        _helperInstaller = StateObject(wrappedValue: helperInstaller)

        let cliInstallChecker = CLIInstallChecker()
        _cliInstallChecker = StateObject(wrappedValue: cliInstallChecker)
        _cliAutoStager = StateObject(wrappedValue: CLIAutoStager(checker: cliInstallChecker))

        let helperUninstaller = HelperUninstaller(onUninstallComplete: {
            helperInstaller.reset()
            cliInstallChecker.check()
        })
        _helperUninstaller = StateObject(wrappedValue: helperUninstaller)
    }

    var body: some Scene {
        // 主管理窗口：现代化磁盘管理独立界面
        Window(L10n.tr("main_window_title", isChinese: settings.isChinese), id: "main-window") {
            MainWindowView(
                appState: appState,
                driveScanner: driveScanner,
                mountController: mountController,
                throughputMonitor: throughputMonitor,
                diskOpController: diskOpController,
                startupManager: startupManager,
                helperInstaller: helperInstaller,
                settings: settings,
                finderOpener: finderOpener
            )
            .environment(\.locale, settings.effectiveLocale)
        }
        .defaultSize(width: 900, height: 600)

        // 偏好设置独立窗口
        Settings {
            MainPreferencesWindowView(
                settings: settings,
                helperInstaller: helperInstaller,
                helperUninstaller: helperUninstaller,
                diagnoseRunner: diagnoseRunner
            )
            .environment(\.locale, settings.effectiveLocale)
        }

        // 菜单栏常驻弹出卡片
        MenuBarExtra {
            PopoverContentView(
                appState: appState,
                driveScanner: driveScanner,
                mountController: mountController,
                throughputMonitor: throughputMonitor,
                remountController: remountController,
                diagnoseRunner: diagnoseRunner,
                helperInstaller: helperInstaller,
                helperUninstaller: helperUninstaller,
                cliInstallChecker: cliInstallChecker,
                cliAutoStager: cliAutoStager,
                settings: settings,
                finderOpener: finderOpener,
                helperClient: helperClient,
                navigation: navigation
            )
            .popoverGlassBackground()
            .environment(\.locale, settings.effectiveLocale)
        } label: {
            StatusIconView(state: helperInstaller.state.isDeniedOrFailed ? .error : appState.state)
                .accessibilityLabel("THLNTFS")
                .task {
                    notificationManager.requestAuthorization()
                    driveScanner.startPolling()
                    mountController.startPolling { driveScanner.drives }
                }
                .onChange(of: driveScanner.drives) { newDrives in
                    autoMountManager.handleDiscoveredDrives(
                        drives: newDrives,
                        mountController: mountController,
                        notificationManager: notificationManager
                    )
                }
                .task(id: helperInstaller.state) {
                    if helperInstaller.state == .installing || helperInstaller.state == .notChecked {
                        cliAutoStager.reset()
                    }
                    guard helperInstaller.state == .installed else { return }
                    await cliAutoStager.stageIfNeeded()
                }
        }
        .menuBarExtraStyle(.window)
    }
}
