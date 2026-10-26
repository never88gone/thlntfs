import SwiftUI

/// 卷级别的个性化偏好设置卡片（自动挂载、只读模式、Spotlight 索引控制与所有权权限）
public struct VolumePreferencesView: View {
    @Binding public var partition: DiskPartition
    public var onSpotlightToggled: ((Bool) -> Void)?
    @Environment(\.locale) private var locale

    private var isChinese: Bool {
        locale.identifier.hasPrefix("zh")
    }

    public init(
        partition: Binding<DiskPartition>,
        onSpotlightToggled: ((Bool) -> Void)? = nil
    ) {
        self._partition = partition
        self.onSpotlightToggled = onSpotlightToggled
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(L10n.tr("pref_card_title", isChinese: isChinese), systemImage: "slider.horizontal.3")
                .font(.system(size: 13, weight: .semibold))

            VStack(spacing: 8) {
                toggleCard(
                    icon: "bolt.badge.automatic.fill",
                    title: L10n.tr("pref_auto_mount", isChinese: isChinese),
                    subtitle: L10n.tr("pref_auto_mount_sub", isChinese: isChinese),
                    isOn: $partition.autoMountEnabled,
                    isDisabled: partition.isInternal
                )

                toggleCard(
                    icon: "lock.fill",
                    title: L10n.tr("pref_readonly_mode", isChinese: isChinese),
                    subtitle: L10n.tr("pref_readonly_mode_sub", isChinese: isChinese),
                    isOn: $partition.isReadOnly,
                    isDisabled: partition.isInternal
                )

                toggleCard(
                    icon: "magnifyingglass.circle.fill",
                    title: L10n.tr("pref_spotlight_index", isChinese: isChinese),
                    subtitle: L10n.tr("pref_spotlight_index_sub", isChinese: isChinese),
                    isOn: Binding(
                        get: { partition.spotlightDisabled },
                        set: { newValue in
                            partition.spotlightDisabled = newValue
                            onSpotlightToggled?(newValue)
                        }
                    ),
                    isDisabled: partition.isInternal || !partition.isMounted
                )

                toggleCard(
                    icon: "person.crop.circle.badge.checkmark",
                    title: L10n.tr("pref_ignore_ownership", isChinese: isChinese),
                    subtitle: L10n.tr("pref_ignore_ownership_sub", isChinese: isChinese),
                    isOn: $partition.ignoreOwnership,
                    isDisabled: partition.isInternal
                )
            }
        }
        .ntfsCardStyle(cornerRadius: 12, padding: 16)
    }

    private func toggleCard(
        icon: String,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>,
        isDisabled: Bool = false
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isDisabled ? Color.secondary.opacity(0.08) : Color.ntfsBlue.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(isDisabled ? .secondary.opacity(0.5) : Color.ntfsBlue)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isDisabled ? .secondary : .primary)
                Text(subtitle)
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .disabled(isDisabled)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.ntfsSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
