import SwiftUI

/// 主窗口左侧边栏，支持磁盘分组展示、搜索过滤与刷新
public struct SidebarView: View {
    @Binding public var selectedPartitionId: String?
    public var partitions: [DiskPartition]
    public var isHelperInstalled: Bool
    public var onRefresh: () -> Void

    @State private var searchText: String = ""

    public init(
        selectedPartitionId: Binding<String?>,
        partitions: [DiskPartition],
        isHelperInstalled: Bool = true,
        onRefresh: @escaping () -> Void = {}
    ) {
        self._selectedPartitionId = selectedPartitionId
        self.partitions = partitions
        self.isHelperInstalled = isHelperInstalled
        self.onRefresh = onRefresh
    }

    @Environment(\.locale) private var locale

    private var isChinese: Bool {
        locale.identifier.hasPrefix("zh")
    }

    private var filteredPartitions: [DiskPartition] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return partitions
        }
        return partitions.filter {
            $0.label.localizedCaseInsensitiveContains(searchText) ||
            $0.bsdName.localizedCaseInsensitiveContains(searchText) ||
            $0.fileSystem.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var groups: [DiskGroup] {
        DiskGroup.group(partitions: filteredPartitions, isChinese: isChinese)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 搜索框 (精致圆角与清除按钮)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 13))
                TextField(L10n.tr("search_disks_placeholder", isChinese: isChinese), text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.ntfsSecondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.ntfsBorderColor, lineWidth: 1)
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()
                .background(Color.ntfsBorderColor)

            // 分组列表
            List(selection: $selectedPartitionId) {
                ForEach(groups) { group in
                    Section(header: sectionHeader(for: group)) {
                        ForEach(group.partitions) { partition in
                            SidebarDiskRow(
                                partition: partition,
                                isSelected: selectedPartitionId == partition.id
                            )
                            .tag(partition.id)
                            .listRowInsets(EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6))
                            .listRowSeparator(.hidden)
                            .onTapGesture {
                                selectedPartitionId = partition.id
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()
                .background(Color.ntfsBorderColor)

            // 底部工具与状态栏
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(isHelperInstalled ? Color.ntfsGreen : Color.ntfsRed)
                        .frame(width: 8, height: 8)
                        .shadow(color: (isHelperInstalled ? Color.ntfsGreen : Color.ntfsRed).opacity(0.4), radius: 2, x: 0, y: 1)
                    Text(isHelperInstalled ? L10n.tr("helper_service_ready", isChinese: isChinese) : L10n.tr("helper_service_not_ready", isChinese: isChinese))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(6)
                        .background(Color.ntfsBadgeBackground)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help(L10n.tr("rescan_disks_hint", isChinese: isChinese))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.ntfsSecondaryBackground)
        }
    }

    private func sectionHeader(for group: DiskGroup) -> some View {
        HStack {
            Label(group.title, systemImage: group.systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            Spacer()
            Text("\(group.partitions.count)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 1.5)
                .background(Color.ntfsBadgeBackground)
                .clipShape(Capsule())
        }
        .padding(.vertical, 2)
    }
}
