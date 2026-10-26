import SwiftUI
import AppKit
import HelperShared

/// 状态指示小圆点
struct PopoverStatusDot: View {
    let color: Color
    let isPulsing: Bool
    @State private var isDim = false

    var body: some View {
        Circle().fill(color).frame(width: 9, height: 9)
            .opacity(isPulsing && isDim ? 0.45 : 1.0)
            .onAppear {
                guard isPulsing else { return }
                withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { isDim = true }
            }
            .accessibilityHidden(true)
    }
}

/// 菜单栏卡片顶部 Header，提供应用状态、状态指示点及一键开启主窗口入口
public struct PopoverHeaderView: View {
    @ObservedObject public var appState: AppState
    @ObservedObject public var driveScanner: DriveScanner
    @ObservedObject public var settings: Settings
    public let onOpenMainWindow: () -> Void

    public init(
        appState: AppState,
        driveScanner: DriveScanner,
        settings: Settings,
        onOpenMainWindow: @escaping () -> Void
    ) {
        self.appState = appState
        self.driveScanner = driveScanner
        self.settings = settings
        self.onOpenMainWindow = onOpenMainWindow
    }

    private var style: StatusIconStyle {
        StatusIcon.style(for: appState.state)
    }

    private var headerSubtitle: String {
        switch appState.state {
        case .idle:
            if driveScanner.drives.isEmpty {
                return L10n.tr("no_drives_found", isChinese: settings.isChinese)
            } else {
                return L10n.tr("drives_detected_format", driveScanner.drives.count, isChinese: settings.isChinese)
            }
        case .mounting:
            return L10n.tr("mounting", isChinese: settings.isChinese)
        case .mountedReadWrite:
            return L10n.tr("mounted_read_write", isChinese: settings.isChinese)
        case .mountedReadOnly, .mountedReadOnlyDirty:
            return L10n.tr("mounted_read_only", isChinese: settings.isChinese)
        case .mountedUnknown:
            return L10n.tr("mount_verification_needed", isChinese: settings.isChinese)
        case .error:
            return L10n.tr("error", isChinese: settings.isChinese)
        }
    }

    public var body: some View {
        let currentStyle = style
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(currentStyle.color.opacity(0.14))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(currentStyle.color.opacity(0.28)))
                DriveHeaderGlyph(color: currentStyle.color)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(L10n.appName())
                    .font(.system(size: 13, weight: .semibold))
                Text(headerSubtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onOpenMainWindow) {
                Image(systemName: "macwindow")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(5)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help(L10n.openMainWindow(isChinese: settings.isChinese))
            .accessibilityLabel(L10n.tr("open_main_window", isChinese: settings.isChinese))

            PopoverStatusDot(color: currentStyle.color, isPulsing: appState.state != .idle && appState.state != .error)
                .help(TooltipCopy.status(for: appState.state))
        }
    }
}
