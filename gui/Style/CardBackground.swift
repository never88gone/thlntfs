import SwiftUI

/// 统一的高质感卡片容器修饰符，适配 macOS 原生毛玻璃与 Paragon 风格精工卡片
public struct CardContainerModifier: ViewModifier {
    public var cornerRadius: CGFloat
    public var padding: CGFloat

    public init(cornerRadius: CGFloat = 12, padding: CGFloat = 18) {
        self.cornerRadius = cornerRadius
        self.padding = padding
    }

    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.ntfsCardBackground)
                    .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                    .shadow(color: Color.black.opacity(0.02), radius: 1, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.ntfsBorderColor, lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.ntfsHighlightBorder, Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            )
    }
}

public extension View {
    func ntfsCardStyle(cornerRadius: CGFloat = 12, padding: CGFloat = 18) -> some View {
        modifier(CardContainerModifier(cornerRadius: cornerRadius, padding: padding))
    }
}
