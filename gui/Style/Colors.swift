import SwiftUI
import AppKit

private extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1.0) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

/// 集中管理的色彩定义。遵循规范：所有颜色值只能写到本文件。
public extension Color {
    init(light: NSColor, dark: NSColor) {
        self.init(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        })
    }

    // MARK: - 品牌与状态色彩
    /// 已挂载读写状态 (Green) - #34C759 light / #30D158 dark
    static let ntfsGreen = Color(light: NSColor(hex: 0x34C759), dark: NSColor(hex: 0x30D158))
    /// 挂载中/主强调色 (Blue) - #007AFF light / #2D9CFF dark
    static let ntfsBlue = Color(light: NSColor(hex: 0x007AFF), dark: NSColor(hex: 0x2D9CFF))
    /// 只读/脏日志告警 (Yellow) - #FFD60A
    static let ntfsYellow = Color(NSColor(hex: 0xFFD60A))
    /// 错误/危险操作 (Red) - #FF453A
    static let ntfsRed = Color(NSColor(hex: 0xFF453A))
    /// 橙色状态指示 (Orange) - #FF9500 light / #FF9F0A dark
    static let ntfsOrange = Color(light: NSColor(hex: 0xFF9500), dark: NSColor(hex: 0xFF9F0A))
    /// 紫色类别标识 (Purple) - #AF52DE light / #BF5AF2 dark
    static let ntfsPurple = Color(light: NSColor(hex: 0xAF52DE), dark: NSColor(hex: 0xBF5AF2))
    /// 靛蓝标识 (Indigo) - #5856D6 light / #5E5CE6 dark
    static let ntfsIndigo = Color(light: NSColor(hex: 0x5856D6), dark: NSColor(hex: 0x5E5CE6))
    /// 青色标识 (Teal) - #30B0C7 light / #40C8E0 dark
    static let ntfsTeal = Color(light: NSColor(hex: 0x30B0C7), dark: NSColor(hex: 0x40C8E0))
    /// 闲置灰色 (Idle Gray)
    static let ntfsIdleGray = Color(light: NSColor.secondaryLabelColor, dark: .white)

    // MARK: - 实时吞吐量与分区谱系色彩 (Throughput & Partitions)
    /// 实时读取吞吐量指示色 (Cyan Blue)
    static let ntfsThroughputRead = Color(light: NSColor(hex: 0x007AFF), dark: NSColor(hex: 0x0A84FF))
    /// 实时写入吞吐量指示色 (Emerald Green)
    static let ntfsThroughputWrite = Color(light: NSColor(hex: 0x34C759), dark: NSColor(hex: 0x30D158))
    /// EFI / 引导保留分区颜色
    static let ntfsPartitionEFI = Color(light: NSColor(hex: 0x8E8E93), dark: NSColor(hex: 0x636366))
    /// NTFS 数据分区颜色
    static let ntfsPartitionNTFS = Color(light: NSColor(hex: 0x007AFF), dark: NSColor(hex: 0x2D9CFF))
    /// 其他文件系统分区颜色
    static let ntfsPartitionOther = Color(light: NSColor(hex: 0xAF52DE), dark: NSColor(hex: 0xBF5AF2))

    // MARK: - 渐变高质感色彩 (Gradients)
    /// 渐变蓝起始
    static let ntfsGradientBlueStart = Color(light: NSColor(hex: 0x007AFF), dark: NSColor(hex: 0x2D9CFF))
    /// 渐变蓝终止
    static let ntfsGradientBlueEnd = Color(light: NSColor(hex: 0x5856D6), dark: NSColor(hex: 0x5E5CE6))
    /// 渐变绿起始
    static let ntfsGradientGreenStart = Color(light: NSColor(hex: 0x34C759), dark: NSColor(hex: 0x30D158))
    /// 渐变绿终止
    static let ntfsGradientGreenEnd = Color(light: NSColor(hex: 0x30B0C7), dark: NSColor(hex: 0x40C8E0))

    // MARK: - 主管理窗口与卡片色彩体系
    /// 主窗口卡片背景色 (带微半透明材质)
    static let ntfsCardBackground = Color(
        light: NSColor(hex: 0xFFFFFF, alpha: 0.94),
        dark: NSColor(hex: 0x232429, alpha: 0.94)
    )
    /// 卡片悬停背景色
    static let ntfsCardHoverBackground = Color(
        light: NSColor(hex: 0xF8F9FA, alpha: 0.98),
        dark: NSColor(hex: 0x2A2B31, alpha: 0.98)
    )
    /// 次级卡片与容器背景色
    static let ntfsSecondaryBackground = Color(
        light: NSColor(hex: 0xF5F6F8, alpha: 0.98),
        dark: NSColor(hex: 0x1A1B1E, alpha: 0.98)
    )
    /// 主工作区背景色
    static let ntfsMainBackground = Color(
        light: NSColor(hex: 0xF8F9FA),
        dark: NSColor(hex: 0x16171A)
    )
    /// 卡片与分割线边框颜色
    static let ntfsBorderColor = Color(
        light: NSColor(hex: 0x000000, alpha: 0.08),
        dark: NSColor(hex: 0xFFFFFF, alpha: 0.12)
    )
    /// 顶部微高光描边 (Inner Highlight)
    static let ntfsHighlightBorder = Color(
        light: NSColor(hex: 0xFFFFFF, alpha: 0.65),
        dark: NSColor(hex: 0xFFFFFF, alpha: 0.16)
    )
    /// 侧边栏选中背景色
    static let ntfsSidebarSelection = Color(
        light: NSColor(hex: 0x007AFF, alpha: 0.14),
        dark: NSColor(hex: 0x007AFF, alpha: 0.28)
    )
    /// 徽章浅底色
    static let ntfsBadgeBackground = Color(
        light: NSColor(hex: 0x000000, alpha: 0.05),
        dark: NSColor(hex: 0xFFFFFF, alpha: 0.08)
    )
    /// 存储容量条形图 - 已用空间色 (Used Capacity)
    static let ntfsCapacityUsed = Color(
        light: NSColor(hex: 0x007AFF),
        dark: NSColor(hex: 0x0A84FF)
    )
    /// 存储容量条形图 - 可用空间色 (Free Capacity)
    static let ntfsCapacityFree = Color(
        light: NSColor(hex: 0xE5E5EA),
        dark: NSColor(hex: 0x3A3A3C)
    )
    /// 存储容量条形图 - 警告空间色 (Warning Capacity)
    static let ntfsCapacityWarning = Color(
        light: NSColor(hex: 0xFF9500),
        dark: NSColor(hex: 0xFF9F0A)
    )
    /// 终端/日志深色背景
    static let ntfsConsoleBackground = Color(
        light: NSColor(hex: 0x1E1E1E),
        dark: NSColor(hex: 0x121212)
    )
    /// 终端/日志前景色
    static let ntfsConsoleText = Color(
        light: NSColor(hex: 0x00FF66),
        dark: NSColor(hex: 0x30D158)
    )

    // MARK: - 毛玻璃与按钮专用色彩 (Glass Theme & Pill Buttons)
    /// 毛玻璃深色基底色
    static let ntfsGlassDarkBase = Color(NSColor(hex: 0x121218))
    /// 危险胶囊按钮 - 深色模式填充色
    static let ntfsPillDangerFillDark = Color(NSColor(hex: 0xFF5050))
    /// 危险胶囊按钮 - 深色模式边框色
    static let ntfsPillDangerBorderDark = Color(NSColor(hex: 0xFF5050))
    /// 危险胶囊按钮 - 深色模式前景色
    static let ntfsPillDangerForegroundDark = Color(NSColor(hex: 0xFF6E6E))
    /// 危险胶囊按钮 - 浅色模式前景色
    static let ntfsPillDangerForegroundLight = Color(NSColor(hex: 0xC81E14))
}
