import SwiftUI

/// 设为启动盘 (Set as Startup Disk) 确认与引导配置模态窗口
public struct StartupDiskSheet: View {
    public let partition: DiskPartition
    @ObservedObject public var startupManager: StartupDiskManager
    public var onDismiss: () -> Void
    @Environment(\.locale) private var locale

    private var isChinese: Bool {
        locale.identifier.hasPrefix("zh")
    }

    @State private var hasConfirmed: Bool = false

    public init(
        partition: DiskPartition,
        startupManager: StartupDiskManager,
        onDismiss: @escaping () -> Void
    ) {
        self.partition = partition
        self.startupManager = startupManager
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // 头部标题与芯片底座
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.ntfsIndigo.opacity(0.12))
                        .frame(width: 48, height: 48)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.ntfsIndigo.opacity(0.25), lineWidth: 1)
                        )
                    Image(systemName: "power.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color.ntfsIndigo)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.tr("startup_sheet_title", isChinese: isChinese))
                        .font(.system(size: 15, weight: .bold))
                    Text(L10n.tr("startup_target_format", partition.label, partition.bsdName, isChinese: isChinese))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            // 引导认证与说明卡片
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color.ntfsGreen)
                    Text(L10n.tr("startup_detected_efi", isChinese: isChinese))
                        .font(.system(size: 12, weight: .semibold))
                }

                Text(L10n.tr("startup_efi_desc", isChinese: isChinese))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
            }
            .padding(14)
            .background(Color.ntfsSecondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.ntfsBorderColor, lineWidth: 1)
            )

            if let message = startupManager.lastMessage {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 12))
                    Text(message)
                        .font(.system(size: 11))
                }
                .foregroundColor(Color.ntfsGreen)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.ntfsGreen.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            // 底部按钮栏
            HStack {
                Spacer()
                Button(L10n.tr("cancel", isChinese: isChinese), action: onDismiss)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("取消")
                    .accessibilityLabel(L10n.tr("cancel", isChinese: isChinese))

                if !hasConfirmed {
                    Button(L10n.tr("startup_confirm_button", isChinese: isChinese)) {
                        hasConfirmed = true
                        Task {
                            _ = await startupManager.setStartupDisk(partition: partition)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.ntfsIndigo)
                    .shadow(color: Color.ntfsIndigo.opacity(0.25), radius: 3, x: 0, y: 1)
                } else {
                    Button(L10n.tr("erase_done", isChinese: isChinese), action: onDismiss)
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(22)
        .frame(width: 460)
    }
}
