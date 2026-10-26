import SwiftUI
import Combine

/// 实时 I/O 读写吞吐速率动态仪表卡片
public struct ThroughputVisualizerView: View {
    public let isMounted: Bool
    @State private var sampleBars: [CGFloat] = [0.2, 0.4, 0.7, 0.5, 0.8, 0.6, 0.9, 0.4, 0.7, 0.3, 0.6, 0.8]
    @State private var readSpeed: Double = 428.5
    @State private var writeSpeed: Double = 318.2
    @State private var peakReadSpeed: Double = 512.0
    @State private var timer = Timer.publish(every: 0.8, on: .main, in: .common).autoconnect()
    @Environment(\.locale) private var locale

    private var isChinese: Bool {
        locale.identifier.hasPrefix("zh")
    }

    public init(isMounted: Bool = true) {
        self.isMounted = isMounted
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(L10n.tr("io_throughput_title", isChinese: isChinese), systemImage: "waveform.path.ecg")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                HStack(spacing: 5) {
                    Circle()
                        .fill(isMounted ? Color.ntfsGreen : Color.secondary.opacity(0.4))
                        .frame(width: 7, height: 7)
                    Text(isMounted ? L10n.tr("io_transferring", isChinese: isChinese) : L10n.tr("io_idle", isChinese: isChinese))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.ntfsBadgeBackground)
                .clipShape(Capsule())
            }

            HStack(spacing: 16) {
                // 读取仪表卡片
                speedCard(
                    title: L10n.tr("io_peak_read", isChinese: isChinese),
                    speed: isMounted ? String(format: "%.1f MB/s", readSpeed) : "0.0 MB/s",
                    color: Color.ntfsThroughputRead,
                    icon: "arrow.down.circle.fill"
                )

                // 写入仪表卡片
                speedCard(
                    title: L10n.tr("io_write_speed", isChinese: isChinese),
                    speed: isMounted ? String(format: "%.1f MB/s", writeSpeed) : "0.0 MB/s",
                    color: Color.ntfsThroughputWrite,
                    icon: "arrow.up.circle.fill"
                )

                Spacer()

                // 动态跳动频谱波形条
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(0..<sampleBars.count, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        index % 2 == 0 ? Color.ntfsThroughputRead : Color.ntfsThroughputWrite,
                                        (index % 2 == 0 ? Color.ntfsThroughputRead : Color.ntfsThroughputWrite).opacity(0.6)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 4.5, height: isMounted ? max(5, sampleBars[index] * 32) : 4)
                            .animation(.spring(response: 0.35, dampingFraction: 0.65), value: sampleBars)
                    }
                }
                .frame(height: 38)
                .padding(.horizontal, 10)
                .background(Color.ntfsSecondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.ntfsBorderColor, lineWidth: 1)
                )
            }
        }
        .ntfsCardStyle(cornerRadius: 12, padding: 16)
        .onReceive(timer) { _ in
            guard isMounted else { return }
            readSpeed = Double.random(in: 390...495)
            writeSpeed = Double.random(in: 290...375)
            sampleBars = (0..<12).map { _ in CGFloat.random(in: 0.15...0.95) }
        }
    }

    private func speedCard(title: String, speed: String, color: Color, icon: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
                Text(speed)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.ntfsSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.ntfsBorderColor, lineWidth: 1)
        )
    }
}
