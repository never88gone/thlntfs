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

    private struct OpenSourceLib: Identifiable {
        let id: String
        let name: String
        let license: String
        let descZh: String
        let descEn: String
        let url: String
    }

    private let thirdPartyLibs: [OpenSourceLib] = [
        OpenSourceLib(
            id: "anylinuxfs",
            name: "anylinuxfs",
            license: "GPL-3.0",
            descZh: "轻量微虚拟化驱动调度引擎，实现免关 SIP 透明挂载 NTFS 与 EXT4",
            descEn: "MicroVM driver mounting engine for transparent NTFS & EXT4 access on macOS",
            url: "https://github.com/nohajc/anylinuxfs"
        ),
        OpenSourceLib(
            id: "linux-kernel",
            name: "Linux Kernel (libkrunfw)",
            license: "GPL-2.0",
            descZh: "定制极简 ARM64 虚拟化内核与模块，内置高性能 NTFS-3G 驱动",
            descEn: "Minimal ARM64 virtualized kernel image with built-in NTFS-3G drivers",
            url: "https://github.com/nohajc/libkrunfw"
        ),
        OpenSourceLib(
            id: "libkrun",
            name: "libkrun",
            license: "Apache-2.0",
            descZh: "动态轻量 MicroVM 虚拟机沙箱运行时，提供硬件级独立安全隔离",
            descEn: "Lightweight MicroVM hypervisor runtime for hardware-level isolation",
            url: "https://github.com/containers/libkrun"
        ),
        OpenSourceLib(
            id: "vmnet-helper",
            name: "vmnet-helper",
            license: "Apache-2.0",
            descZh: "Apple 官方虚拟机网络特权网桥辅助程序，建立宿主主机通信",
            descEn: "Privileged helper to configure host-only vmnet network bridge",
            url: "https://github.com/nirs/vmnet-helper"
        ),
        OpenSourceLib(
            id: "gvproxy",
            name: "gvproxy (gvisor-tap-vsock)",
            license: "Apache-2.0",
            descZh: "高速虚拟网络通道与用户空间代理，保障内外网络安全隔离传输",
            descEn: "High-performance virtual network proxy connecting host and MicroVM",
            url: "https://github.com/containers/gvisor-tap-vsock"
        ),
        OpenSourceLib(
            id: "alpine-linux",
            name: "Alpine Linux",
            license: "Mixed (GPL/MIT)",
            descZh: "极简轻量容器基础用户态环境，提供外置文件系统检查与维护工具",
            descEn: "Minimal container environment for guest userland tools",
            url: "https://alpinelinux.org"
        ),
    ]

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

                // 开源组件与第三方库
                settingGroup(title: L10n.tr("third_party_group_title", isChinese: isChinese), icon: "shippingbox.fill") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.tr("third_party_group_subtitle", isChinese: isChinese))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(spacing: 8) {
                            ForEach(thirdPartyLibs) { lib in
                                libraryRow(lib)
                            }
                        }

                        Divider()
                            .padding(.vertical, 2)

                        HStack {
                            Spacer()
                            Button {
                                openThirdPartyLicenseFile()
                            } label: {
                                Label(L10n.tr("view_license_file", isChinese: isChinese), systemImage: "doc.text.magnifyingglass")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .buttonStyle(.link)
                            Spacer()
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Color.ntfsMainBackground)
    }

    private func libraryRow(_ lib: OpenSourceLib) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(lib.name)
                        .font(.system(size: 12, weight: .semibold))
                    Text(lib.license)
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Color.ntfsBlue.opacity(0.12))
                        .foregroundColor(Color.ntfsBlue)
                        .clipShape(Capsule())
                }
                Text(isChinese ? lib.descZh : lib.descEn)
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button {
                if let url = URL(string: lib.url) {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help(lib.url)
        }
        .padding(8)
        .background(Color.ntfsSecondaryBackground.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func openThirdPartyLicenseFile() {
        if let bundleUrl = Bundle.main.url(forResource: "THIRD_PARTY_LICENSES", withExtension: "md") {
            NSWorkspace.shared.open(bundleUrl)
            return
        }
        // 回退查找应用支持目录或源代码目录
        let projectPath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("THIRD_PARTY_LICENSES.md")
        if FileManager.default.fileExists(atPath: projectPath.path) {
            NSWorkspace.shared.open(projectPath)
            return
        }
        if let fallbackUrl = URL(string: "https://github.com/never88gone/thlntfs/blob/main/THIRD_PARTY_LICENSES.md") {
            NSWorkspace.shared.open(fallbackUrl)
        }
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
