import SwiftUI
import AppKit

/// 卷硬件参数与元数据详细属性卡片
public struct VolumeAttributesView: View {
    public let partition: DiskPartition
    @State private var copiedKey: String? = nil
    @Environment(\.locale) private var locale

    private var isChinese: Bool {
        locale.identifier.hasPrefix("zh")
    }

    public init(partition: DiskPartition) {
        self.partition = partition
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(L10n.tr("attr_title", isChinese: isChinese), systemImage: "info.circle.fill")
                .font(.system(size: 13, weight: .semibold))

            VStack(spacing: 6) {
                attributeRow(
                    icon: "terminal.fill",
                    title: L10n.tr("attr_device_identifier", isChinese: isChinese),
                    value: "/dev/\(partition.bsdName)",
                    canCopy: true
                )

                attributeRow(
                    icon: "folder.fill",
                    title: L10n.tr("attr_mount_point", isChinese: isChinese),
                    value: partition.mountPoint ?? L10n.tr("attr_unmounted_val", isChinese: isChinese),
                    canCopy: partition.isMounted
                )

                attributeRow(
                    icon: "cable.connector",
                    title: L10n.tr("attr_connection_bus", isChinese: isChinese),
                    value: partition.busProtocol.rawValue
                )

                attributeRow(
                    icon: "doc.text.fill",
                    title: L10n.tr("attr_filesystem", isChinese: isChinese),
                    value: partition.fileSystem.rawValue
                )

                attributeRow(
                    icon: "shield.lefthalf.filled",
                    title: L10n.tr("attr_access_permission", isChinese: isChinese),
                    value: accessModeDescription,
                    valueColor: accessModeColor
                )

                attributeRow(
                    icon: "key.fill",
                    title: L10n.tr("attr_volume_uuid", isChinese: isChinese),
                    value: partition.uuid,
                    canCopy: true
                )
            }
        }
        .ntfsCardStyle(cornerRadius: 12, padding: 16)
    }

    private func attributeRow(
        icon: String,
        title: String,
        value: String,
        valueColor: Color = .primary,
        canCopy: Bool = false
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(Color.ntfsBlue)
                .frame(width: 16)

            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .leading)

            Spacer()

            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(valueColor)
                .lineLimit(1)

            if canCopy {
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(value, forType: .string)
                    copiedKey = title
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        if copiedKey == title { copiedKey = nil }
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: copiedKey == title ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11))
                        if copiedKey == title {
                            Text(L10n.tr("copied", isChinese: isChinese))
                                .font(.system(size: 10, weight: .medium))
                        }
                    }
                    .foregroundColor(copiedKey == title ? Color.ntfsGreen : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.ntfsBadgeBackground)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help(L10n.tr("copy_to_clipboard", isChinese: isChinese))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.ntfsSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var accessModeDescription: String {
        if !partition.isMounted {
            return L10n.tr("attr_unmounted_val", isChinese: isChinese)
        }
        if partition.isDirty {
            return L10n.tr("status_dirty_readonly", isChinese: isChinese)
        }
        if partition.isReadOnly {
            return L10n.tr("attr_read_only_val", isChinese: isChinese)
        }
        return L10n.tr("attr_read_write_val", isChinese: isChinese)
    }

    private var accessModeColor: Color {
        if !partition.isMounted {
            return .secondary
        }
        if partition.isDirty {
            return Color.ntfsYellow
        }
        if partition.isReadOnly {
            return Color.ntfsOrange
        }
        return Color.ntfsGreen
    }
}
