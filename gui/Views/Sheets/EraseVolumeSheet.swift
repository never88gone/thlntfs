import SwiftUI

/// 抹掉并格式化为 NTFS 文件系统的高级配置模态弹窗
public struct EraseVolumeSheet: View {
    public let partition: DiskPartition
    @ObservedObject public var diskOpController: DiskOperationController
    public var onDismiss: () -> Void
    @Environment(\.locale) private var locale

    private var isChinese: Bool {
        locale.identifier.hasPrefix("zh")
    }

    @State private var newVolumeName: String = "UNTITLED"
    @State private var selectedFileSystem: DiskPartition.FileSystemType = .ntfs
    @State private var allocationUnitSize: Int = 4096
    @State private var isQuickFormat: Bool = true
    @State private var hasConfirmed: Bool = false

    public init(
        partition: DiskPartition,
        diskOpController: DiskOperationController,
        onDismiss: @escaping () -> Void
    ) {
        self.partition = partition
        self.diskOpController = diskOpController
        self.onDismiss = onDismiss
        self._newVolumeName = State(initialValue: partition.label.isEmpty ? "UNTITLED" : partition.label)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // 头部警告与标题
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.ntfsRed.opacity(0.12))
                        .frame(width: 48, height: 48)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.ntfsRed.opacity(0.25), lineWidth: 1)
                        )
                    Image(systemName: "trash.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color.ntfsRed)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.tr("erase_title_format", partition.label, isChinese: isChinese))
                        .font(.system(size: 15, weight: .bold))
                    Text(L10n.tr("erase_warning_format", partition.bsdName, isChinese: isChinese))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            if !hasConfirmed {
                // 格式化参数配置表单
                VStack(spacing: 12) {
                    HStack {
                        Text(L10n.tr("erase_new_name", isChinese: isChinese))
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 90, alignment: .leading)
                        TextField("UNTITLED", text: $newVolumeName)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack {
                        Text(L10n.tr("erase_filesystem", isChinese: isChinese))
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 90, alignment: .leading)
                        Picker("", selection: $selectedFileSystem) {
                            Text(L10n.tr("erase_fs_ntfs", isChinese: isChinese)).tag(DiskPartition.FileSystemType.ntfs)
                            Text(L10n.tr("erase_fs_exfat", isChinese: isChinese)).tag(DiskPartition.FileSystemType.exfat)
                            Text(L10n.tr("erase_fs_fat32", isChinese: isChinese)).tag(DiskPartition.FileSystemType.fat32)
                        }
                        .pickerStyle(.menu)
                    }

                    HStack {
                        Text(L10n.tr("erase_cluster_size", isChinese: isChinese))
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 90, alignment: .leading)
                        Picker("", selection: $allocationUnitSize) {
                            Text(L10n.tr("erase_cluster_default", isChinese: isChinese)).tag(4096)
                            Text(L10n.tr("erase_cluster_8k", isChinese: isChinese)).tag(8192)
                            Text(L10n.tr("erase_cluster_16k", isChinese: isChinese)).tag(16384)
                            Text(L10n.tr("erase_cluster_32k", isChinese: isChinese)).tag(32768)
                            Text(L10n.tr("erase_cluster_64k", isChinese: isChinese)).tag(65536)
                        }
                        .pickerStyle(.menu)
                    }

                    Toggle(L10n.tr("erase_quick_format", isChinese: isChinese), isOn: $isQuickFormat)
                        .font(.system(size: 12))
                        .toggleStyle(.checkbox)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(14)
                .background(Color.ntfsSecondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.ntfsBorderColor, lineWidth: 1)
                )
            } else {
                // 进度与终端控制台
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
                    .frame(height: 130)
                    .background(Color.ntfsConsoleBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
            }

            // 底部按钮栏
            HStack {
                Spacer()
                if !hasConfirmed {
                    Button(L10n.tr("cancel", isChinese: isChinese), action: onDismiss)
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("取消")
                        .accessibilityLabel(L10n.tr("cancel", isChinese: isChinese))

                    Button(L10n.tr("erase_button", isChinese: isChinese), role: .destructive) {
                        hasConfirmed = true
                        Task {
                            _ = await diskOpController.eraseAsNTFS(
                                partition: partition,
                                newLabel: newVolumeName,
                                clusterSize: allocationUnitSize,
                                quickFormat: isQuickFormat
                            )
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.ntfsRed)
                    .disabled(newVolumeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } else {
                    Button(diskOpController.isOperating ? L10n.tr("erase_in_progress", isChinese: isChinese) : L10n.tr("erase_done", isChinese: isChinese)) {
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
}
