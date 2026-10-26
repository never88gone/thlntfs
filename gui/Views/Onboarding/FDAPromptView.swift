import SwiftUI
import AppKit
import HelperShared

public enum FDAPromptCopy {
    public static let helperServiceName = AppIdentifiers.helperBundleId
    public static let instructions = "macOS lists THLNTFS Helper under its technical service name, \(helperServiceName), and may show a generic executable icon because the helper is a standalone privileged tool. Enable that exact entry in Full Disk Access. If it is not listed, add it with the '+' button."
}

/// 引导用户授予特权辅助服务“完全磁盘访问权限 (Full Disk Access)”的模态提示组件
public struct FDAPromptView: View {
    public let onOpenSettings: () -> Void
    public let onCancel: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale

    private var isChinese: Bool {
        locale.identifier.hasPrefix("zh")
    }

    public init(onOpenSettings: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.onOpenSettings = onOpenSettings
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.ntfsYellow.opacity(0.14))
                        .overlay(Circle().strokeBorder(Color.ntfsYellow.opacity(0.3)))
                        .frame(width: 40, height: 40)
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.ntfsYellow)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.fdaRequiredTitle(isChinese: isChinese))
                        .font(.system(size: 14, weight: .semibold))
                    Text(L10n.fdaRequiredSubtitle(isChinese: isChinese))
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(FDAPromptCopy.instructions)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                Button(L10n.cancel(isChinese: isChinese)) {
                    onCancel()
                }
                .buttonStyle(.glassNeutral(colorScheme: colorScheme))

                Spacer()

                Button(L10n.fdaOpenSettings(isChinese: isChinese)) {
                    onOpenSettings()
                }
                .buttonStyle(.glassPrimary())
            }
        }
        .padding(20)
        .frame(width: 340)
    }
}
