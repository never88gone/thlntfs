import Foundation

/// 统一的磁盘分区/卷模型，兼容 Paragon 风格主视图与菜单栏
public struct DiskPartition: Identifiable, Hashable, Sendable {
    public let id: String
    public var bsdName: String
    public var label: String
    public var fileSystem: FileSystemType
    public var totalBytes: Int64
    public var freeBytes: Int64
    public var mountPoint: String?
    public var isMounted: Bool
    public var isReadOnly: Bool
    public var isDirty: Bool
    public var busProtocol: BusProtocol
    public var uuid: String
    public var isInternal: Bool
    public var autoMountEnabled: Bool
    public var spotlightDisabled: Bool
    public var ignoreOwnership: Bool

    public enum FileSystemType: String, Sendable, CaseIterable {
        case ntfs = "NTFS"
        case apfs = "APFS"
        case exfat = "exFAT"
        case fat32 = "FAT32"
        case hfsPlus = "Mac OS Extended (HFS+)"
        case ext4 = "ext4"
        case unknown = "Unknown"

        public var isNTFS: Bool {
            self == .ntfs
        }
    }

    public enum BusProtocol: String, Sendable {
        case usb = "USB"
        case thunderbolt = "Thunderbolt"
        case pcie = "PCI-Express"
        case nvme = "NVMe"
        case virtual = "Virtual"
        case unknown = "External"
    }

    public var usedBytes: Int64 {
        max(0, totalBytes - freeBytes)
    }

    public var usagePercentage: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }

    public var formattedTotal: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }

    public var formattedUsed: String {
        ByteCountFormatter.string(fromByteCount: usedBytes, countStyle: .file)
    }

    public var formattedFree: String {
        ByteCountFormatter.string(fromByteCount: freeBytes, countStyle: .file)
    }

    public init(
        id: String = UUID().uuidString,
        bsdName: String,
        label: String,
        fileSystem: FileSystemType = .ntfs,
        totalBytes: Int64 = 0,
        freeBytes: Int64 = 0,
        mountPoint: String? = nil,
        isMounted: Bool = false,
        isReadOnly: Bool = false,
        isDirty: Bool = false,
        busProtocol: BusProtocol = .usb,
        uuid: String = UUID().uuidString,
        isInternal: Bool = false,
        autoMountEnabled: Bool = true,
        spotlightDisabled: Bool = false,
        ignoreOwnership: Bool = true
    ) {
        self.id = id
        self.bsdName = bsdName
        self.label = label.isEmpty ? bsdName : label
        self.fileSystem = fileSystem
        self.totalBytes = totalBytes
        self.freeBytes = freeBytes
        self.mountPoint = mountPoint
        self.isMounted = isMounted
        self.isReadOnly = isReadOnly
        self.isDirty = isDirty
        self.busProtocol = busProtocol
        self.uuid = uuid
        self.isInternal = isInternal
        self.autoMountEnabled = autoMountEnabled
        self.spotlightDisabled = spotlightDisabled
        self.ignoreOwnership = ignoreOwnership
    }
}

public extension DiskPartition {
    static let mockNTFS = DiskPartition(
        bsdName: "disk2s1",
        label: "TOSHIBA_EXT",
        fileSystem: .ntfs,
        totalBytes: 2_000_000_000_000,
        freeBytes: 800_000_000_000,
        mountPoint: "/Volumes/TOSHIBA_EXT",
        isMounted: true,
        isReadOnly: false,
        isDirty: false,
        busProtocol: .usb,
        uuid: "E2B8-892C-3F01-9A82",
        isInternal: false
    )

    static let mockDirtyNTFS = DiskPartition(
        bsdName: "disk3s2",
        label: "Bootcamp_Data",
        fileSystem: .ntfs,
        totalBytes: 512_000_000_000,
        freeBytes: 120_000_000_000,
        mountPoint: "/Volumes/Bootcamp_Data",
        isMounted: true,
        isReadOnly: true,
        isDirty: true,
        busProtocol: .usb,
        uuid: "7A99-44F1-BC32-110A",
        isInternal: false
    )

    static let mockExFAT = DiskPartition(
        bsdName: "disk4s1",
        label: "SD_CARD_64G",
        fileSystem: .exfat,
        totalBytes: 64_000_000_000,
        freeBytes: 32_000_000_000,
        mountPoint: "/Volumes/SD_CARD_64G",
        isMounted: true,
        isReadOnly: false,
        isDirty: false,
        busProtocol: .usb,
        uuid: "9812-EF01",
        isInternal: false
    )

    static let mockInternalAPFS = DiskPartition(
        bsdName: "disk1s1",
        label: "Macintosh HD",
        fileSystem: .apfs,
        totalBytes: 1_000_000_000_000,
        freeBytes: 450_000_000_000,
        mountPoint: "/",
        isMounted: true,
        isReadOnly: true,
        isDirty: false,
        busProtocol: .nvme,
        uuid: "4A09-91B2-CC41-9981",
        isInternal: true
    )
}
