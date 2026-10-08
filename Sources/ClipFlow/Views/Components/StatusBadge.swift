import SwiftUI

public struct StatusBadge: View {
    public let text: String
    public let icon: String?
    public let color: Color

    public init(text: String, icon: String? = nil, color: Color = .accentColor) {
        self.text = text
        self.icon = icon
        self.color = color
    }

    public var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
            }
            Text(text)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .foregroundColor(color)
        .background(
            Capsule()
                .fill(color.opacity(0.12))
        )
    }
}
