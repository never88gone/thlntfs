// swift-tools-version: 6.0
import Foundation
import PackageDescription

// GUI + privileged-helper package (PLAN.md Phase 3). Targets are added to incrementally as
// later §6 units land — this file only declares what `3-xpc-helper` needs.

// `#filePath` gives this manifest's own absolute path regardless of the CWD `swift build` is
// invoked from (build/package-app.sh, CI, or Xcode) — resolving helper/Info.plist and
// helper/launchd.plist relative to that is the only path-independent way to feed them to the
// linker below.
let packageDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let helperInfoPlistPath = packageDir.appendingPathComponent("helper/Info.plist").path
let helperLaunchdPlistPath = packageDir.appendingPathComponent("helper/launchd.plist").path

let package = Package(
    name: "thlntfs-gui",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "HelperShared", targets: ["HelperShared"]),
        .executable(name: "thlntfs-helper", targets: ["thlntfs-helper"]),
        .library(name: "THLNTFSGUI", targets: ["THLNTFSGUI"]),
        .executable(name: "thlntfs-gui", targets: ["thlntfs-gui"]),
    ],
    targets: [
        .target(
            name: "HelperShared",
            path: "helper",
            exclude: ["main.swift", "Info.plist", "launchd.plist"],
            sources: ["AppIdentifiers.swift", "HelperProtocol.swift", "HelperService.swift", "GeneratedCLIManifest.swift"]
        ),
        .executableTarget(
            name: "thlntfs-helper",
            dependencies: ["HelperShared"],
            path: "helper",
            exclude: ["AppIdentifiers.swift", "HelperProtocol.swift", "HelperService.swift", "GeneratedCLIManifest.swift", "Info.plist", "launchd.plist"],
            sources: ["main.swift"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", helperInfoPlistPath,
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__launchd_plist",
                    "-Xlinker", helperLaunchdPlistPath,
                ])
            ]
        ),
        .target(
            name: "THLNTFSGUI",
            dependencies: ["HelperShared"],
            path: "gui",
            exclude: ["App", "Resources", "Info.plist"],
            sources: [
                "Helper/HelperClient.swift", "Status/StatusIcon.swift", "State/AppState.swift",
                "State/SingleInstanceGuard.swift", "State/PopoverNavigation.swift",
                "Drives/DriveScanner.swift", "Drives/ThroughputMonitor.swift",
                "Drives/DiskPartition.swift", "Drives/DiskGroup.swift",
                "Drives/SystemDiskScanner.swift",
                "Actions/MountSnapshot.swift", "Actions/MountController.swift",
                "Actions/RemountController.swift", "Actions/FinderOpener.swift",
                "Actions/PreferencesOpener.swift", "Actions/CLIAutoStager.swift",
                "Actions/DiagnoseRunner.swift", "Actions/DeveloperDiagnoseExport.swift",
                "Actions/DiagnoseSummary.swift", "Actions/DiskOperationController.swift",
                "Actions/NotificationManager.swift", "Actions/StartupDiskManager.swift",
                "Actions/AutoMountManager.swift",
                "FirstRun/HelperInstaller.swift", "FirstRun/HelperUninstaller.swift",
                "FirstRun/CLIInstallChecker.swift",
                "Preferences/ProductVersion.swift", "Preferences/Settings.swift",
                "Preferences/PreferencesView.swift",
                "Style/Colors.swift", "Style/GlassTheme.swift", "Style/Icons.swift",
                "Style/PillButtons.swift", "Style/TooltipCopy.swift", "Style/CardBackground.swift",
                "Style/L10n.swift",
                "Views/Popover/PopoverContentView.swift", "Views/Popover/PopoverHeaderView.swift",
                "Views/Popover/PopoverFooterView.swift", "Views/Popover/PopoverEmptyStateView.swift",
                "Views/Popover/DriveRow.swift", "Views/Popover/DirtyBanner.swift",
                "Views/Popover/SpeedBar.swift", "Views/Popover/SecurityIndicators.swift",
                "Views/Onboarding/FirstRunView.swift", "Views/Onboarding/CLIMissingView.swift",
                "Views/Onboarding/FDAPromptView.swift", "Views/Onboarding/DiagnosePanel.swift",
                "Views/Previews/AllPreviews.swift",
                "Views/MainWindow/SidebarDiskRow.swift", "Views/MainWindow/SidebarView.swift",
                "Views/MainWindow/VolumeCapacityChartView.swift", "Views/MainWindow/VolumeActionBarView.swift",
                "Views/MainWindow/ThroughputVisualizerView.swift", "Views/MainWindow/PartitionMapVisualizerView.swift",
                "Views/MainWindow/VolumeAttributesView.swift", "Views/MainWindow/VolumePreferencesView.swift",
                "Views/MainWindow/VolumeDetailView.swift", "Views/MainWindow/MainWindowView.swift",
                "Views/Sheets/EraseVolumeSheet.swift", "Views/Sheets/VerifyRepairSheet.swift",
                "Views/Sheets/RenameVolumeSheet.swift", "Views/Sheets/StartupDiskSheet.swift",
                "Views/Preferences/GeneralSettingsTab.swift", "Views/Preferences/DriverPerformanceTab.swift",
                "Views/Preferences/SecurityIsolationTab.swift", "Views/Preferences/DiagnosticsAboutTab.swift",
                "Views/Preferences/MainPreferencesWindowView.swift",
            ]
        ),
        .executableTarget(
            name: "thlntfs-gui",
            dependencies: ["THLNTFSGUI"],
            path: "gui",
            exclude: [
                "Helper", "Status", "State", "Drives", "Views", "Actions", "FirstRun", "Preferences",
                "Style", "Resources", "Info.plist",
            ],
            sources: ["App/THLNTFSApp.swift", "App/DemoScaffold.swift"]
        ),
    ]
)
