import SwiftUI
import AppKit

/// 偏好设置 - 系统诊断与关于选项卡
public struct DiagnosticsAboutTab: View {
    @ObservedObject public var diagnoseRunner: DiagnoseRunner
    @State private var showingExportSuccess: Bool = false
    @Environment(\.locale) private var locale

    private var isChinese: Bool {
        locale.identifier.hasPrefix("zh")
    }

    public init(diagnoseRunner: DiagnoseRunner) {
        self.diagnoseRunner = diagnoseRunner
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 系统自检与诊断
                settingGroup(title: L10n.tr("diag_group_title", isChinese: isChinese), icon: "heart.text.square.fill") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.tr("diag_item_title", isChinese: isChinese))
                                    .font(.system(size: 12.5, weight: .medium))
                                Text(L10n.tr("diag_item_desc", isChinese: isChinese))
                                    .font(.system(size: 10.5))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button(diagnoseRunner.isRunning ? L10n.tr("diag_btn_running", isChinese: isChinese) : L10n.tr("diag_btn_run", isChinese: isChinese)) {
                                Task { await diagnoseRunner.run() }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.ntfsBlue)
                            .shadow(color: Color.ntfsBlue.opacity(0.25), radius: 3, x: 0, y: 1)
                            .disabled(diagnoseRunner.isRunning)
                        }

                        if let report = diagnoseRunner.report {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(DiagnoseSummary.rows(for: report)) { row in
                                    HStack {
                                        Text(row.label)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text(row.value)
                                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                            .foregroundColor(row.isHealthy ? Color.ntfsGreen : Color.ntfsOrange)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.ntfsSecondaryBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            }
                        }
                    }
                }

                // 产品关于信息
                settingGroup(title: L10n.tr("about_group_title", isChinese: isChinese), icon: "info.circle.fill") {
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.ntfsBlue.opacity(0.12))
                                .frame(width: 56, height: 56)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.ntfsBlue.opacity(0.25), lineWidth: 1)
                                 )
                            Image(systemName: "externaldrive.badge.checkmark")
                                .font(.system(size: 28))
                                .foregroundColor(Color.ntfsBlue)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(L10n.tr("about_app_name", isChinese: isChinese))
                                .font(.system(size: 15, weight: .bold))
                            Text(L10n.tr("about_version_desc", isChinese: isChinese))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)

                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color.ntfsGreen)
                                Text(L10n.tr("about_sip_desc", isChinese: isChinese))
                                    .font(.system(size: 10.5, weight: .medium))
                                    .foregroundColor(Color.ntfsGreen)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Color.ntfsMainBackground)
    }

    private func settingGroup<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .padding(12)
            .ntfsCardStyle(cornerRadius: 12, padding: 0)
        }
    }
}
