import SwiftUI

/// 偏好设置 - 常规设置选项卡
public struct GeneralSettingsTab: View {
    @ObservedObject public var settings: Settings

    public init(settings: Settings) {
        self.settings = settings
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 界面语言与偏好
                settingGroup(
                    title: L10n.languageSection(isChinese: settings.isChinese),
                    icon: "globe"
                ) {
                    HStack(alignment: .center, spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.ntfsBlue.opacity(0.12))
                                .frame(width: 32, height: 32)
                            Image(systemName: "character.bubble.fill")
                                .font(.system(size: 15))
                                .foregroundColor(Color.ntfsBlue)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.languageTitle(isChinese: settings.isChinese))
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundColor(.primary)
                            Text(L10n.languageSubtitle(isChinese: settings.isChinese))
                                .font(.system(size: 10.5))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Picker("", selection: $settings.language) {
                            ForEach(AppLanguage.allCases) { lang in
                                Text(lang.displayName).tag(lang)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 160)
                        .accessibilityIdentifier("语言切换选择器")
                    }
                    .padding(10)
                    .background(Color.ntfsSecondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                // 系统启动与集成
                settingGroup(
                    title: L10n.tr("system_integration_group", isChinese: settings.isChinese),
                    icon: "macwindow.badge.plus"
                ) {
                    settingToggle(
                        icon: "power.circle.fill",
                        title: L10n.tr("launch_at_login_title_full", isChinese: settings.isChinese),
                        subtitle: L10n.tr("launch_at_login_sub_full", isChinese: settings.isChinese),
                        isOn: $settings.launchAtLogin
                    )
                }

                // 自动化行为
                settingGroup(
                    title: L10n.tr("auto_mount_group", isChinese: settings.isChinese),
                    icon: "bolt.badge.automatic.fill"
                ) {
                    VStack(spacing: 8) {
                        settingToggle(
                            icon: "bolt.horizontal.fill",
                            title: L10n.tr("auto_mount_new_drives", isChinese: settings.isChinese),
                            subtitle: L10n.tr("auto_mount_new_drives_sub", isChinese: settings.isChinese),
                            isOn: $settings.autoMountNewDrives
                        )

                        settingToggle(
                            icon: "bell.badge.fill",
                            title: L10n.tr("notifications_enabled", isChinese: settings.isChinese),
                            subtitle: L10n.tr("notifications_enabled_sub", isChinese: settings.isChinese),
                            isOn: $settings.notificationsEnabled
                        )
                    }
                }

                // 访达集成
                settingGroup(
                    title: L10n.tr("finder_integration_group", isChinese: settings.isChinese),
                    icon: "folder.badge.gearshape"
                ) {
                    settingToggle(
                        icon: "folder.fill",
                        title: L10n.tr("open_finder_on_mount", isChinese: settings.isChinese),
                        subtitle: L10n.tr("open_finder_on_mount_sub", isChinese: settings.isChinese),
                        isOn: $settings.openFinderOnMount
                    )
                }
            }
            .padding(20)
        }
        .background(Color.ntfsMainBackground)
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

    private func settingToggle(
        icon: String,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.ntfsBlue.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(Color.ntfsBlue)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding(10)
        .background(Color.ntfsSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
