import SwiftUI

/// 独立的全局偏好设置窗口，提供 4 个专业配置选项卡
public struct MainPreferencesWindowView: View {
    @ObservedObject public var settings: Settings
    @ObservedObject public var helperInstaller: HelperInstaller
    @ObservedObject public var helperUninstaller: HelperUninstaller
    @ObservedObject public var diagnoseRunner: DiagnoseRunner

    public init(
        settings: Settings,
        helperInstaller: HelperInstaller,
        helperUninstaller: HelperUninstaller,
        diagnoseRunner: DiagnoseRunner = DiagnoseRunner()
    ) {
        self.settings = settings
        self.helperInstaller = helperInstaller
        self.helperUninstaller = helperUninstaller
        self.diagnoseRunner = diagnoseRunner
    }

    public var body: some View {
        TabView {
            GeneralSettingsTab(settings: settings)
                .tabItem {
                    Label(L10n.general(isChinese: settings.isChinese), systemImage: "gearshape")
                }

            DriverPerformanceTab(settings: settings)
                .tabItem {
                    Label(L10n.driverPerformance(isChinese: settings.isChinese), systemImage: "bolt.fill")
                }

            SecurityIsolationTab(
                helperInstaller: helperInstaller,
                helperUninstaller: helperUninstaller
            )
            .tabItem {
                Label(L10n.securityIsolation(isChinese: settings.isChinese), systemImage: "lock.shield.fill")
            }

            DiagnosticsAboutTab(diagnoseRunner: diagnoseRunner)
                .tabItem {
                    Label(L10n.diagnosticsAbout(isChinese: settings.isChinese), systemImage: "info.circle")
                }
        }
        .frame(width: 580, height: 530)
    }
}
