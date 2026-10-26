import Foundation
import HelperShared

/// 负责探测宿主 macOS 真实外置物理磁盘与内置核心磁盘的扫描器
@MainActor
public final class SystemDiskScanner: ObservableObject {
    @Published public private(set) var physicalPartitions: [DiskPartition] = []
    @Published public private(set) var isScanning: Bool = false
    @Published public private(set) var lastScanError: String?

    public init() {}

    /// 执行全量物理磁盘扫描
    public func scan() async -> [DiskPartition] {
        isScanning = true
        lastScanError = nil

        let partitions = await Task.detached(priority: .userInitiated) {
            Self.performDiskutilScan()
        }.value

        self.physicalPartitions = partitions
        self.isScanning = false
        return partitions
    }

    /// 安全卸载外置磁盘卷 (严格限制在合法设备上，禁止操作系统关键卷)
    public func unmount(partition: DiskPartition) async -> Bool {
        guard !partition.isInternal else { return false }
        guard validateDevice(partition.bsdName) else { return false }

        return await Task.detached(priority: .userInitiated) {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
            p.arguments = ["unmount", partition.bsdName]
            let pipe = Pipe()
            p.standardOutput = pipe
            p.standardError = pipe
            do {
                try p.run()
                p.waitUntilExit()
                return p.terminationStatus == 0
            } catch {
                return false
            }
        }.value
    }

    /// 安全挂载外置磁盘卷
    public func mount(partition: DiskPartition) async -> Bool {
        guard !partition.isInternal else { return false }
        guard validateDevice(partition.bsdName) else { return false }

        return await Task.detached(priority: .userInitiated) {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
            p.arguments = ["mount", partition.bsdName]
            let pipe = Pipe()
            p.standardOutput = pipe
            p.standardError = pipe
            do {
                try p.run()
                p.waitUntilExit()
                return p.terminationStatus == 0
            } catch {
                return false
            }
        }.value
    }

    // MARK: - 私有底层扫描实现

    private nonisolated static func performDiskutilScan() -> [DiskPartition] {
        var result: [DiskPartition] = []

        // 1. 扫描物理外置磁盘
        let externalIdents = fetchExternalPhysicalIdentifiers()
        for ident in externalIdents {
            if let partition = probePartition(identifier: ident, isInternal: false) {
                result.append(partition)
            }
        }

        // 2. 扫描系统内置主磁盘
        if let internalPartition = probeInternalMainDisk() {
            result.append(internalPartition)
        }

        return result
    }

    /// 获取所有真实的物理外置分区标识符 (排除 Disk Image 等虚拟设备)
    private nonisolated static func fetchExternalPhysicalIdentifiers() -> [String] {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        p.arguments = ["list", "-plist", "external"]
        let pipe = Pipe()
        p.standardOutput = pipe
        do {
            try p.run()
        } catch {
            return []
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()

        guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let allDisks = plist["AllDisksAndPartitions"] as? [[String: Any]] else {
            return []
        }

        var identifiers: [String] = []
        for disk in allDisks {
            // 排除系统内部介质
            if let isOSInternal = disk["OSInternal"] as? Bool, isOSInternal {
                continue
            }

            let partitions = disk["Partitions"] as? [[String: Any]] ?? []
            for part in partitions {
                guard let ident = part["DeviceIdentifier"] as? String else { continue }
                if validateDevice(ident) {
                    identifiers.append(ident)
                }
            }

            let apfsVols = disk["APFSVolumes"] as? [[String: Any]] ?? []
            for vol in apfsVols {
                guard let ident = vol["DeviceIdentifier"] as? String else { continue }
                let mp = vol["MountPoint"] as? String ?? ""
                if mp.contains("CoreSimulator") { continue }
                if validateDevice(ident) {
                    identifiers.append(ident)
                }
            }
        }
        return identifiers
    }

    /// 探测特定分区的详细硬件与文件系统属性
    private nonisolated static func probePartition(identifier: String, isInternal: Bool) -> DiskPartition? {
        guard validateDevice(identifier) else { return nil }

        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        p.arguments = ["info", "-plist", identifier]
        let pipe = Pipe()
        p.standardOutput = pipe
        do {
            try p.run()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()

        guard let info = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return nil
        }

        let busProtocolStr = info["BusProtocol"] as? String ?? "USB"
        // 彻底过滤虚拟磁盘镜像
        if busProtocolStr.localizedCaseInsensitiveContains("Disk Image") ||
           busProtocolStr.localizedCaseInsensitiveContains("Virtual") {
            return nil
        }

        let rawLabel = info["VolumeName"] as? String ?? ""
        let label = rawLabel.isEmpty ? identifier : rawLabel
        let fsName = info["FilesystemName"] as? String ?? (info["FilesystemType"] as? String ?? "")
        let mountPoint = info["MountPoint"] as? String
        let isMounted = (mountPoint != nil && !mountPoint!.isEmpty)
        let total = info["TotalSize"] as? Int64 ?? (info["Size"] as? Int64 ?? 0)
        let free = info["FreeSpace"] as? Int64 ?? 0
        let uuid = info["VolumeUUID"] as? String ?? UUID().uuidString
        let isReadOnly = info["Writable"] as? Bool == false

        let fileSystem: DiskPartition.FileSystemType
        let lowerFs = fsName.lowercased()
        if lowerFs.contains("ntfs") {
            fileSystem = .ntfs
        } else if lowerFs.contains("fat32") || lowerFs.contains("msdos") || lowerFs.contains("fat") {
            fileSystem = .fat32
        } else if lowerFs.contains("exfat") {
            fileSystem = .exfat
        } else if lowerFs.contains("apfs") {
            fileSystem = .apfs
        } else if lowerFs.contains("hfs") {
            fileSystem = .hfsPlus
        } else if lowerFs.contains("ext4") {
            fileSystem = .ext4
        } else {
            fileSystem = .unknown
        }

        let busProtocol: DiskPartition.BusProtocol
        let lowerBus = busProtocolStr.lowercased()
        if lowerBus.contains("usb") {
            busProtocol = .usb
        } else if lowerBus.contains("thunderbolt") {
            busProtocol = .thunderbolt
        } else if lowerBus.contains("pci") {
            busProtocol = .pcie
        } else if lowerBus.contains("nvme") {
            busProtocol = .nvme
        } else {
            busProtocol = .usb
        }

        return DiskPartition(
            id: identifier,
            bsdName: identifier,
            label: label,
            fileSystem: fileSystem,
            totalBytes: total,
            freeBytes: free,
            mountPoint: isMounted ? mountPoint : nil,
            isMounted: isMounted,
            isReadOnly: isReadOnly,
            isDirty: false,
            busProtocol: busProtocol,
            uuid: uuid,
            isInternal: isInternal
        )
    }

    /// 探测系统内置主分区
    private nonisolated static func probeInternalMainDisk() -> DiskPartition? {
        let keys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeUUIDStringKey
        ]
        let rootURL = URL(fileURLWithPath: "/")
        guard let values = try? rootURL.resourceValues(forKeys: Set(keys)) else {
            return nil
        }

        let name = values.volumeName ?? "Macintosh HD"
        let total = Int64(values.volumeTotalCapacity ?? 2_000_000_000_000)
        let free = Int64(values.volumeAvailableCapacity ?? 800_000_000_000)
        let uuid = values.volumeUUIDString ?? "INTERNAL-SYSTEM-ROOT"

        return DiskPartition(
            id: "system_internal_disk",
            bsdName: "disk0s2",
            label: name,
            fileSystem: .apfs,
            totalBytes: total,
            freeBytes: free,
            mountPoint: "/",
            isMounted: true,
            isReadOnly: false,
            isDirty: false,
            busProtocol: .pcie,
            uuid: uuid,
            isInternal: true
        )
    }
}
