import SwiftUI

public enum DiagnosePanelPhase: Equatable, Sendable {
    case hidden
    case running
    case result
    case error
    case empty
}

/// 诊断面板可见性与呈现状态
public struct DiagnosePanelPresentation: Equatable, Sendable {
    public private(set) var isVisible = false

    public init() {}

    public mutating func show() { isVisible = true }
    public mutating func hide() { isVisible = false }

    public func phase(report: DiagnoseReport?, errorMessage: String?, isRunning: Bool) -> DiagnosePanelPhase {
        guard isVisible else { return .hidden }
        if isRunning { return .running }
        if report != nil { return .result }
        if errorMessage != nil { return .error }
        return .empty
    }
}

/// 诊断摘要面板视图组件
public struct DiagnosePanel: View {
    @ObservedObject public var runner: DiagnoseRunner
    public let mountState: MountState?
    public let onHide: (() -> Void)?
    @Environment(\.locale) private var locale

    private var isChinese: Bool {
        locale.identifier.hasPrefix("zh")
    }

    public init(runner: DiagnoseRunner) {
        self.runner = runner
        self.mountState = nil
        self.onHide = nil
    }

    public init(runner: DiagnoseRunner, onHide: @escaping () -> Void) {
        self.runner = runner
        self.mountState = nil
        self.onHide = onHide
    }

    public init(runner: DiagnoseRunner, mountState: MountState?, onHide: (() -> Void)? = nil) {
        self.runner = runner
        self.mountState = mountState
        self.onHide = onHide
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let onHide {
                HStack(spacing: 8) {
                    Text(L10n.tr("diagnostics_panel_title", isChinese: isChinese))
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Button(L10n.tr("hide", isChinese: isChinese), action: onHide)
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Hide diagnostics")
                        .help("Hide the diagnostic panel")
                }
            }

            Group {
                if let report = runner.report {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(DiagnoseSummary.rows(for: report, mountState: mountState)) { row in
                            Label("\(row.label): \(row.value)", systemImage: iconName(for: row.status))
                                .foregroundStyle(color(for: row.status))
                                .font(.caption)
                                .help(row.explanation)
                                .accessibilityHint(row.explanation)
                        }
                    }
                } else if let errorMessage = runner.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(Color.ntfsRed.opacity(0.95))
                } else if runner.isRunning {
                    ProgressView().frame(maxWidth: .infinity)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(panelBackgroundColor))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(panelBorderColor))
        .padding(.top, 4)
    }

    private var panelBackgroundColor: Color {
        runner.errorMessage == nil ? Color.secondary.opacity(0.08) : Color.ntfsRed.opacity(0.09)
    }

    private var panelBorderColor: Color {
        runner.errorMessage == nil ? Color.secondary.opacity(0.12) : Color.ntfsRed.opacity(0.2)
    }

    private func iconName(for status: DiagnoseStatus) -> String {
        switch status {
        case .healthy: "checkmark.circle"
        case .informational: "info.circle"
        case .warning: "exclamationmark.circle"
        case .unavailable: "questionmark.circle"
        }
    }

    private func color(for status: DiagnoseStatus) -> Color {
        switch status {
        case .healthy: .primary
        case .informational: .ntfsBlue
        case .warning: .orange
        case .unavailable: .secondary
        }
    }
}
