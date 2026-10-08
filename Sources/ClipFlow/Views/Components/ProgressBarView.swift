import SwiftUI

public struct ProgressBarView: View {
    public let progress: Double
    public let height: CGFloat
    public let accentColor: Color

    public init(
        progress: Double,
        height: CGFloat = 6,
        accentColor: Color = .red
    ) {
        self.progress = min(max(progress, 0.0), 1.0)
        self.height = height
        self.accentColor = accentColor
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.08))
                    .frame(height: height)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [accentColor.opacity(0.85), accentColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(geometry.size.width * CGFloat(progress), 0), height: height)
                    .animation(.easeInOut(duration: 0.25), value: progress)
            }
        }
        .frame(height: height)
    }
}
