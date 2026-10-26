import SwiftUI

/// 卷标重命名模态窗口
public struct RenameVolumeSheet: View {
    public let partition: DiskPartition
    @ObservedObject public var diskOpController: DiskOperationController
    public var onRenameConfirmed: (String) -> Void
    public var onDismiss: () -> Void
    @Environment(\.locale) private var locale

    private var isChinese: Bool {
        locale.identifier.hasPrefix("zh")
    }

    @State private var newLabel: String = ""

    public init(
        partition: DiskPartition,
        diskOpController: DiskOperationController,
        onRenameConfirmed: @escaping (String) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.partition = partition
        self.diskOpController = diskOpController
        self.onRenameConfirmed = onRenameConfirmed
        self.onDismiss = onDismiss
        self._newLabel = State(initialValue: partition.label)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // 头部标题与芯片级图标底座
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.ntfsBlue.opacity(0.12))
                        .frame(width: 48, height: 48)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.ntfsBlue.opacity(0.25), lineWidth: 1)
                        )
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color.ntfsBlue)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.tr("rename_sheet_title", isChinese: isChinese))
                        .font(.system(size: 15, weight: .bold))
                    Text(L10n.tr("rename_device_node_format", partition.bsdName, partition.fileSystem.rawValue, isChinese: isChinese))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            // 输入表单卡片
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(L10n.tr("rename_input_label", isChinese: isChinese))
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Text(L10n.tr("rename_char_count_format", newLabel.count, isChinese: isChinese))
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                TextField(L10n.tr("rename_placeholder", isChinese: isChinese), text: $newLabel)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, weight: .medium))

                Text(L10n.tr("rename_hint", isChinese: isChinese))
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(Color.ntfsSecondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.ntfsBorderColor, lineWidth: 1)
            )

            // 底部按钮栏
            HStack {
                Spacer()
                Button(L10n.tr("cancel", isChinese: isChinese), action: onDismiss)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("取消")
                    .accessibilityLabel(L10n.tr("cancel", isChinese: isChinese))

                Button(L10n.tr("rename_confirm_button", isChinese: isChinese)) {
                    let trimmed = newLabel.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onRenameConfirmed(trimmed)
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.ntfsBlue)
                .shadow(color: Color.ntfsBlue.opacity(0.25), radius: 3, x: 0, y: 1)
                .disabled(newLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(22)
        .frame(width: 420)
    }
}
