import SwiftUI

/// 卷顶部核心操作按钮栏（挂载/卸载、在访达中打开、验证修复、抹掉、设为启动盘）
public struct VolumeActionBarView: View {
    public let partition: DiskPartition
    public var isBootable: Bool
    public var onMount: () -> Void
    public var onUnmount: () -> Void
    public var onOpenFinder: () -> Void
    public var onVerifyRepair: () -> Void
    public var onErase: () -> Void
    public var onSetStartupDisk: () -> Void
    @Environment(\.locale) private var locale

    private var isChinese: Bool {
        locale.identifier.hasPrefix("zh")
    }

    public init(
        partition: DiskPartition,
        isBootable: Bool = false,
        onMount: @escaping () -> Void = {},
        onUnmount: @escaping () -> Void = {},
        onOpenFinder: @escaping () -> Void = {},
        onVerifyRepair: @escaping () -> Void = {},
        onErase: @escaping () -> Void = {},
        onSetStartupDisk: @escaping () -> Void = {}
    ) {
        self.partition = partition
        self.isBootable = isBootable
        self.onMount = onMount
        self.onUnmount = onUnmount
        self.onOpenFinder = onOpenFinder
        self.onVerifyRepair = onVerifyRepair
        self.onErase = onErase
        self.onSetStartupDisk = onSetStartupDisk
    }

    public var body: some View {
        HStack(spacing: 10) {
            // 挂载 / 卸载主按钮 (带有醒目品牌色彩与微阴影)
            if partition.isMounted {
                Button(action: onUnmount) {
                    HStack(spacing: 6) {
                        Image(systemName: "eject.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text(L10n.unmount(isChinese: isChinese))
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.ntfsRed)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .shadow(color: Color.ntfsRed.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("卸载")
                .accessibilityLabel(L10n.unmount(isChinese: isChinese))
            } else {
                Button(action: onMount) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text(L10n.mount(isChinese: isChinese))
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(partition.isInternal ? Color.secondary.opacity(0.3) : Color.ntfsBlue)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .shadow(color: partition.isInternal ? Color.clear : Color.ntfsBlue.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .disabled(partition.isInternal)
                .accessibilityIdentifier("挂载 (读/写)")
                .accessibilityLabel(L10n.mount(isChinese: isChinese))
            }

            // 在访达中打开
            actionButton(
                title: L10n.openInFinder(isChinese: isChinese),
                icon: "folder.fill",
                isEnabled: partition.isMounted,
                action: onOpenFinder
            )

            // 验证与修复
            actionButton(
                title: L10n.verifyAndRepair(isChinese: isChinese),
                icon: "stethoscope",
                isEnabled: !partition.isInternal,
                action: onVerifyRepair
            )

            // 抹掉 / 格式化
            actionButton(
                title: L10n.erase(isChinese: isChinese),
                icon: "trash",
                isEnabled: !partition.isInternal,
                action: onErase
            )

            // 设为启动盘
            if isBootable {
                actionButton(
                    title: L10n.setStartupDisk(isChinese: isChinese),
                    icon: "power.circle.fill",
                    isEnabled: true,
                    action: onSetStartupDisk
                )
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func actionButton(
        title: String,
        icon: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(Color.ntfsSecondaryBackground)
            .foregroundColor(isEnabled ? .primary : .secondary.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.ntfsBorderColor, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.02), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityIdentifier(title)
        .accessibilityLabel(title)
    }
}
