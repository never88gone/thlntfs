import SwiftUI
import AppKit

/// No-drives empty-state copy, extracted as testable constants
public enum EmptyStateCopy {
    public static let title = "No NTFS / ext drives connected"
    public static let subtitle = "Connect an NTFS or ext drive to\nget started"
}

/// 菜单栏卡片无磁盘时的空状态组件
public struct PopoverEmptyStateView: View {
    public let onRefresh: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale

    private var isChinese: Bool {
        locale.identifier.hasPrefix("zh")
    }

    public init(onRefresh: @escaping () -> Void) {
        self.onRefresh = onRefresh
    }

    public var body: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.secondary.opacity(0.12)))
                DriveGlyphEmpty(color: .secondary)
            }
            .frame(width: 44, height: 44)

            VStack(spacing: 4) {
                Text(L10n.tr("empty_state_title", isChinese: isChinese))
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(L10n.tr("empty_state_subtitle", isChinese: isChinese))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            Button {
                onRefresh()
            } label: {
                HStack(spacing: 6) {
                    RefreshGlyph()
                    Text(L10n.tr("refresh", isChinese: isChinese))
                }
            }
            .buttonStyle(.glassNeutral(colorScheme: colorScheme))
            .help(TooltipCopy.text(for: .refresh))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}
