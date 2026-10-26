import SwiftUI

/// 偏好设置 - 驱动引擎与 I/O 吞吐调优选项卡
public struct DriverPerformanceTab: View {
    @ObservedObject public var settings: Settings
    @State private var selectedDriver: String = "ntfs-3g"
    @State private var bufferSizeIndex: Int = 2
    @State private var asyncWriteEnabled: Bool = true
    @Environment(\.locale) private var locale

    private var isChinese: Bool {
        locale.identifier.hasPrefix("zh")
    }

    public init(settings: Settings) {
        self.settings = settings
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 核心驱动引擎
                settingGroup(title: L10n.tr("driver_engine_group", isChinese: isChinese), icon: "cpu") {
                    VStack(spacing: 8) {
                        driverOptionCard(
                            id: "ntfs-3g",
                            name: L10n.tr("driver_fuse_name", isChinese: isChinese),
                            desc: L10n.tr("driver_fuse_desc", isChinese: isChinese),
                            badge: L10n.tr("driver_fuse_badge", isChinese: isChinese)
                        )

                        driverOptionCard(
                            id: "ntfs3",
                            name: L10n.tr("driver_ntfs3_name", isChinese: isChinese),
                            desc: L10n.tr("driver_ntfs3_desc", isChinese: isChinese),
                            badge: L10n.tr("driver_ntfs3_badge", isChinese: isChinese)
                        )
                    }
                }

                // I/O 缓冲区与并发调优
                settingGroup(title: L10n.tr("nfs_buffer_tuning_group", isChinese: isChinese), icon: "speedometer") {
                    VStack(spacing: 10) {
                        HStack {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.ntfsTeal.opacity(0.12))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "square.stack.3d.down.right.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.ntfsTeal)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.tr("io_chunk_size", isChinese: isChinese))
                                    .font(.system(size: 12.5, weight: .medium))
                                Text(L10n.tr("io_chunk_desc", isChinese: isChinese))
                                    .font(.system(size: 10.5))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Picker("", selection: $bufferSizeIndex) {
                                Text(L10n.tr("chunk_64k", isChinese: isChinese)).tag(0)
                                Text(L10n.tr("chunk_128k", isChinese: isChinese)).tag(1)
                                Text(L10n.tr("chunk_256k", isChinese: isChinese)).tag(2)
                                Text(L10n.tr("chunk_512k", isChinese: isChinese)).tag(3)
                            }
                            .pickerStyle(.menu)
                            .frame(width: 170)
                        }
                        .padding(10)
                        .background(Color.ntfsSecondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        HStack(alignment: .center, spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.ntfsGreen.opacity(0.12))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 15))
                                    .foregroundColor(Color.ntfsGreen)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.tr("async_flush", isChinese: isChinese))
                                    .font(.system(size: 12.5, weight: .medium))
                                Text(L10n.tr("async_flush_desc", isChinese: isChinese))
                                    .font(.system(size: 10.5))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Toggle("", isOn: $asyncWriteEnabled)
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }
                        .padding(10)
                        .background(Color.ntfsSecondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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

    private func driverOptionCard(id: String, name: String, desc: String, badge: String) -> some View {
        Button(action: { selectedDriver = id }) {
            HStack(spacing: 12) {
                Image(systemName: selectedDriver == id ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 16))
                    .foregroundColor(selectedDriver == id ? Color.ntfsBlue : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(name)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(.primary)

                        Text(badge)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(selectedDriver == id ? Color.ntfsBlue.opacity(0.15) : Color.ntfsBadgeBackground)
                            .foregroundColor(selectedDriver == id ? Color.ntfsBlue : .secondary)
                            .clipShape(Capsule())
                    }

                    Text(desc)
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(10)
            .background(Color.ntfsSecondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(selectedDriver == id ? Color.ntfsBlue.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
