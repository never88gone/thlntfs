import SwiftUI

/// 文件系统急救修复与脏日志重置模态窗口
public struct VerifyRepairSheet: View {
    public let partition: DiskPartition
    @ObservedObject public var diskOpController: DiskOperationController
    public var onDismiss: () -> Void
    @Environment(\.locale) private var locale

    private var isChinese: Bool {
        locale.identifier.hasPrefix("zh")
    }

    @State private var hasStarted: Bool = false

    public init(
        partition: DiskPartition,
        diskOpController: DiskOperationController,
        onDismiss: @escaping () -> Void
    ) {
        self.partition = partition
        self.diskOpController = diskOpController
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // 头部标题
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.ntfsBlue.opacity(0.12))
                        .frame(width: 48, height: 48)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.ntfsBlue.opacity(0.25), lineWidth: 1)
                        )
                    Image(systemName: "stethoscope")
                        .font(.system(size: 22))
                        .foregroundColor(Color.ntfsBlue)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.tr("repair_title_format", partition.label, isChinese: isChinese))
                        .font(.system(size: 15, weight: .bold))
                    Text(L10n.tr("repair_subtitle", isChinese: isChinese))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            if !hasStarted {
                // 急救项目预检清单卡片
                VStack(alignment: .leading, spacing: 10) {
                    checkItem(
                        title: L10n.tr("repair_item_1_title", isChinese: isChinese),
                        subtitle: L10n.tr("repair_item_1_sub", isChinese: isChinese)
                    )
                    Divider().background(Color.ntfsBorderColor)
                    checkItem(
                        title: L10n.tr("repair_item_2_title", isChinese: isChinese),
                        subtitle: L10n.tr("repair_item_2_sub", isChinese: isChinese)
                    )
                    Divider().background(Color.ntfsBorderColor)
                    checkItem(
                        title: L10n.tr("repair_item_3_title", isChinese: isChinese),
                        subtitle: L10n.tr("repair_item_3_sub", isChinese: isChinese)
                    )
                }
                .padding(14)
                .background(Color.ntfsSecondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.ntfsBorderColor, lineWidth: 1)
                )
            } else {
                // 运行进度与控制台日志输出
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        ProgressView(value: diskOpController.operationProgress)
                        Text("\(Int(diskOpController.operationProgress * 100))%")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }

                    ScrollView {
                        Text(diskOpController.operationLogs.joined(separator: "\n"))
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundColor(Color.ntfsConsoleText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                    }
                    .frame(height: 140)
                    .background(Color.ntfsConsoleBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
            }

            // 底部操作栏
            HStack {
                Spacer()
                if !hasStarted {
                    Button(L10n.tr("cancel", isChinese: isChinese), action: onDismiss)
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("取消")
                        .accessibilityLabel(L10n.tr("cancel", isChinese: isChinese))

                    Button(L10n.tr("repair_start_button", isChinese: isChinese)) {
                        hasStarted = true
                        Task {
                            _ = await diskOpController.verifyAndRepair(partition: partition)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.ntfsBlue)
                    .shadow(color: Color.ntfsBlue.opacity(0.25), radius: 3, x: 0, y: 1)
                } else {
                    Button(diskOpController.isOperating ? L10n.tr("repair_in_progress", isChinese: isChinese) : L10n.tr("repair_done", isChinese: isChinese)) {
                        onDismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(diskOpController.isOperating)
                }
            }
        }
        .padding(22)
        .frame(width: 500)
    }

    private func checkItem(title: String, subtitle: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(Color.ntfsGreen)
                .font(.system(size: 15))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
            }
        }
    }
}
