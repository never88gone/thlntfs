import SwiftUI
import AppKit

/// 顶部紧凑型版本更新提醒横幅，适用于菜单栏弹出框及主窗口
public struct UpdateBannerView: View {
    @ObservedObject public var updateChecker: UpdateChecker
    public let isChinese: Bool
    public let onOpenDetails: () -> Void

    public init(
        updateChecker: UpdateChecker,
        isChinese: Bool,
        onOpenDetails: @escaping () -> Void
    ) {
        self.updateChecker = updateChecker
        self.isChinese = isChinese
        self.onOpenDetails = onOpenDetails
    }

    public var body: some View {
        if updateChecker.shouldShowBanner, let update = updateChecker.availableUpdate {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 15))
                    .foregroundColor(Color.ntfsBlue)

                VStack(alignment: .leading, spacing: 1) {
                    Text(L10n.tr("update_banner_title", update.version, isChinese: isChinese))
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(L10n.tr("update_banner_subtitle", updateChecker.currentVersion, isChinese: isChinese))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Button(L10n.tr("update_btn_upgrade", isChinese: isChinese)) {
                    onOpenDetails()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.ntfsBlue)
                .controlSize(.small)

                Button {
                    updateChecker.dismissBannerForNow()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)
                .help(L10n.tr("update_btn_later", isChinese: isChinese))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.ntfsBlue.opacity(0.10))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.ntfsBlue.opacity(0.28), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

/// 完整的版本更新详情弹窗（适用于主管理窗口与偏好设置窗口的 .sheet）
public struct UpdateSheetView: View {
    @ObservedObject public var updateChecker: UpdateChecker
    public let isChinese: Bool

    public init(updateChecker: UpdateChecker, isChinese: Bool) {
        self.updateChecker = updateChecker
        self.isChinese = isChinese
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 头部图标与标题
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.ntfsBlue.opacity(0.14))
                        .frame(width: 52, height: 52)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.ntfsBlue.opacity(0.3), lineWidth: 1)
                        )
                    Image(systemName: "sparkles")
                        .font(.system(size: 24))
                        .foregroundColor(Color.ntfsBlue)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.tr("update_sheet_title", isChinese: isChinese))
                        .font(.system(size: 16, weight: .bold))
                    if let update = updateChecker.availableUpdate {
                        Text(L10n.tr("update_sheet_versions", update.version, updateChecker.currentVersion, isChinese: isChinese))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }

            if let update = updateChecker.availableUpdate {
                // 更新日志区域
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.tr("update_release_notes_title", isChinese: isChinese))
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(.secondary)

                    ScrollView {
                        Text(update.releaseNotes.isEmpty ? L10n.tr("update_release_notes_empty", isChinese: isChinese) : update.releaseNotes)
                            .font(.system(size: 11.5))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(10)
                    }
                    .frame(height: 170)
                    .background(Color.ntfsSecondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                }

                // 底部操作按钮
                HStack(spacing: 8) {
                    Button(L10n.tr("update_btn_skip_version", isChinese: isChinese)) {
                        updateChecker.skipVersion(update.version)
                    }
                    .buttonStyle(.bordered)

                    Button(L10n.tr("update_btn_view_github", isChinese: isChinese)) {
                        updateChecker.openReleasePage()
                    }
                    .buttonStyle(.link)
                    .font(.system(size: 11.5))

                    Spacer()

                    Button(L10n.tr("update_btn_later", isChinese: isChinese)) {
                        updateChecker.isPresentingUpdateSheet = false
                    }
                    .buttonStyle(.bordered)

                    Button {
                        updateChecker.openPreferredDownload()
                        updateChecker.isPresentingUpdateSheet = false
                    } label: {
                        Label(
                            update.dmgDownloadURL != nil
                                ? L10n.tr("update_btn_download_dmg", isChinese: isChinese)
                                : L10n.tr("update_btn_go_download", isChinese: isChinese),
                            systemImage: "arrow.down.circle.fill"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.ntfsBlue)
                }
            }
        }
        .padding(20)
        .frame(width: 480)
        .background(Color.ntfsMainBackground)
    }
}
