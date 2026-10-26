import Foundation

/// 磁盘与卷的分类分组模型，驱动 Paragon 风格侧边栏
public struct DiskGroup: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let systemImage: String
    public var partitions: [DiskPartition]

    public init(
        id: String,
        title: String,
        systemImage: String,
        partitions: [DiskPartition]
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.partitions = partitions
    }

    public static func group(partitions: [DiskPartition], isChinese: Bool = true) -> [DiskGroup] {
        var ntfsList: [DiskPartition] = []
        var externalOtherList: [DiskPartition] = []
        var internalList: [DiskPartition] = []

        for item in partitions {
            if item.isInternal {
                internalList.append(item)
            } else if item.fileSystem.isNTFS {
                ntfsList.append(item)
            } else {
                externalOtherList.append(item)
            }
        }

        var groups: [DiskGroup] = []

        if !ntfsList.isEmpty {
            groups.append(
                DiskGroup(
                    id: "ntfs",
                    title: L10n.tr("group_ntfs_volumes", isChinese: isChinese),
                    systemImage: "externaldrive.fill.badge.checkmark",
                    partitions: ntfsList
                )
            )
        }

        if !externalOtherList.isEmpty {
            groups.append(
                DiskGroup(
                    id: "external",
                    title: L10n.tr("group_other_external", isChinese: isChinese),
                    systemImage: "externaldrive",
                    partitions: externalOtherList
                )
            )
        }

        if !internalList.isEmpty {
            groups.append(
                DiskGroup(
                    id: "internal",
                    title: L10n.tr("group_internal_disks", isChinese: isChinese),
                    systemImage: "internaldrive",
                    partitions: internalList
                )
            )
        }

        return groups
    }
}
