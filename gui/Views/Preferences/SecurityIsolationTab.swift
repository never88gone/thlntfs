import SwiftUI
import HelperShared

/// 偏好设置 - 特权服务与网络安全隔离选项卡
public struct SecurityIsolationTab: View {
    @ObservedObject public var helperInstaller: HelperInstaller
    @ObservedObject public var helperUninstaller: HelperUninstaller
    @Environment(\.locale) private var locale

    private var isChinese: Bool {
        locale.identifier.hasPrefix("zh")
    }

    public init(
        helperInstaller: HelperInstaller,
        helperUninstaller: HelperUninstaller
    ) {
        self.helperInstaller = helperInstaller
        self.helperUninstaller = helperUninstaller
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 特权辅助守护进程 (Privileged Helper)
                settingGroup(title: L10n.tr("pref_helper_daemon_group", isChinese: isChinese), icon: "shield.checkerboard") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(helperStatusColor.opacity(0.12))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(helperStatusColor)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(AppIdentifiers.helperBundleId)
                                    .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                                Text(helperStatusText)
                                    .font(.system(size: 11))
                                    .foregroundColor(helperStatusColor)
                            }

                            Spacer()

                            if helperInstaller.state != .installed {
                                Button(L10n.tr("pref_install_register_btn", isChinese: isChinese)) {
                                    Task {
                                        helperInstaller.reset()
                                        await helperInstaller.installIfNeeded()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Color.ntfsBlue)
                                .shadow(color: Color.ntfsBlue.opacity(0.25), radius: 3, x: 0, y: 1)
                            } else {
                                Button(L10n.tr("pref_uninstall_helper_btn", isChinese: isChinese), role: .destructive) {
                                    Task { await helperUninstaller.uninstallEverything() }
                                }
                                .buttonStyle(.bordered)
                            }
                        }

                        Text(L10n.tr("pref_security_desc", isChinese: isChinese))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineSpacing(2)
                    }
                }

                // 虚拟网络与防火墙隔离
                settingGroup(title: L10n.tr("pref_net_isolation_title", isChinese: isChinese), icon: "network.badge.shield.half.filled") {
                    VStack(spacing: 8) {
                        isolationFeatureCard(
                            icon: "point.3.filled.connected.trianglepath.dotted",
                            title: L10n.tr("pref_vmnet_title", isChinese: isChinese),
                            subtitle: L10n.tr("pref_vmnet_desc", isChinese: isChinese)
                        )

                        isolationFeatureCard(
                            icon: "flame.fill",
                            title: L10n.tr("pref_pf_title", isChinese: isChinese),
                            subtitle: L10n.tr("pref_pf_desc", isChinese: isChinese)
                        )
                    }
                }
            }
            .padding(20)
        }
        .background(Color.ntfsMainBackground)
        .onAppear {
            Task {
                await helperInstaller.installIfNeeded()
            }
        }
    }

    private func settingGroup<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .padding(12)
            .ntfsCardStyle(cornerRadius: 12, padding: 0)
        }
    }

    private func isolationFeatureCard(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.ntfsGreen.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(Color.ntfsGreen)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Color.ntfsGreen)
                .font(.system(size: 14))
        }
        .padding(10)
        .background(Color.ntfsSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var helperStatusText: String {
        switch helperInstaller.state {
        case .installed: return L10n.tr("pref_helper_running", isChinese: isChinese)
        case .installing: return L10n.tr("pref_helper_installing", isChinese: isChinese)
        case .failed: return L10n.tr("pref_helper_failed", isChinese: isChinese)
        case .denied: return L10n.tr("pref_helper_denied", isChinese: isChinese)
        default: return L10n.tr("pref_helper_not_installed", isChinese: isChinese)
        }
    }

    private var helperStatusColor: Color {
        switch helperInstaller.state {
        case .installed: return Color.ntfsGreen
        case .failed, .denied: return Color.ntfsRed
        default: return .secondary
        }
    }
}
