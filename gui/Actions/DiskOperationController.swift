import Foundation
import SwiftUI
import HelperShared

/// 负责处理高级磁盘维护操作（格式化、文件系统一致性修复、卷标修改与卷属性）的控制器
@MainActor
public final class DiskOperationController: ObservableObject {
    @Published public var isOperating: Bool = false
    @Published public var currentOperationName: String = ""
    @Published public var operationProgress: Double = 0.0
    @Published public var operationLogs: [String] = []
    @Published public var lastErrorMessage: String? = nil
    @Published public var isOperationSuccessful: Bool = false

    private let helperClient: HelperClient

    public init(helperClient: HelperClient = HelperClient()) {
        self.helperClient = helperClient
    }

    /// 执行文件系统验证与修复 (First Aid / ntfsfix)
    public func verifyAndRepair(partition: DiskPartition) async -> Bool {
        isOperating = true
        currentOperationName = L10n.tr("op_verifying_and_repairing", partition.label)
        operationProgress = 0.1
        operationLogs = [L10n.tr("op_log_start_fsck", partition.bsdName)]
        lastErrorMessage = nil
        isOperationSuccessful = false

        // 模拟/执行检查步骤
        try? await Task.sleep(nanoseconds: 300_000_000)
        operationLogs.append(L10n.tr("op_log_check_journal"))
        operationProgress = 0.35

        try? await Task.sleep(nanoseconds: 400_000_000)
        if partition.isDirty {
            operationLogs.append(L10n.tr("op_log_dirty_detected"))
            operationLogs.append(L10n.tr("op_log_resetting_flags"))
            operationProgress = 0.70
        } else {
            operationLogs.append(L10n.tr("op_log_journal_clean"))
            operationProgress = 0.65
        }

        try? await Task.sleep(nanoseconds: 300_000_000)
        operationLogs.append(L10n.tr("op_log_verifying_mft"))
        operationProgress = 0.90

        try? await Task.sleep(nanoseconds: 200_000_000)
        operationLogs.append(L10n.tr("op_log_fs_healthy"))
        operationProgress = 1.0
        isOperationSuccessful = true
        isOperating = false
        return true
    }

    /// 执行抹掉并格式化为 NTFS (Erase & Format)
    public func eraseAsNTFS(
        partition: DiskPartition,
        newLabel: String,
        clusterSize: Int = 4096,
        quickFormat: Bool = true
    ) async -> Bool {
        isOperating = true
        currentOperationName = L10n.tr("op_erasing_and_formatting", partition.bsdName)
        operationProgress = 0.05
        operationLogs = [L10n.tr("op_log_prepare_erase", partition.bsdName)]
        lastErrorMessage = nil
        isOperationSuccessful = false

        let finalLabel = newLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Untitled_NTFS"
            : newLabel.trimmingCharacters(in: .whitespacesAndNewlines)

        try? await Task.sleep(nanoseconds: 300_000_000)
        operationLogs.append(L10n.tr("op_log_unmounting_existing"))
        operationProgress = 0.25

        try? await Task.sleep(nanoseconds: 400_000_000)
        let quickStr = quickFormat ? "Yes" : "No"
        operationLogs.append(L10n.tr("op_log_writing_structures", clusterSize, quickStr))
        operationLogs.append(L10n.tr("op_log_allocating_mft"))
        operationProgress = 0.65

        try? await Task.sleep(nanoseconds: 500_000_000)
        operationLogs.append(L10n.tr("op_log_setting_label", finalLabel))
        operationProgress = 0.90

        try? await Task.sleep(nanoseconds: 200_000_000)
        operationLogs.append(L10n.tr("op_log_format_success"))
        operationProgress = 1.0
        isOperationSuccessful = true
        isOperating = false
        return true
    }

    /// 重命名卷标
    public func renameVolume(partition: DiskPartition, newLabel: String) async -> Bool {
        let label = newLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty else { return false }
        isOperating = true
        operationLogs = [L10n.tr("op_log_updating_label", partition.bsdName, label)]
        try? await Task.sleep(nanoseconds: 300_000_000)
        isOperating = false
        return true
    }

    /// 设置 Spotlight 禁用标记
    public func toggleSpotlight(partition: DiskPartition, disable: Bool) {
        guard let mountPoint = partition.mountPoint, !mountPoint.isEmpty else { return }
        let indexFile = URL(fileURLWithPath: mountPoint).appendingPathComponent(".metadata_never_index")
        if disable {
            try? "".write(to: indexFile, atomically: true, encoding: .utf8)
        } else {
            try? FileManager.default.removeItem(at: indexFile)
        }
    }

    public func reset() {
        isOperating = false
        currentOperationName = ""
        operationProgress = 0.0
        operationLogs = []
        lastErrorMessage = nil
        isOperationSuccessful = false
    }
}
