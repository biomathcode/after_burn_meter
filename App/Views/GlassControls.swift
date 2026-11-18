import SwiftUI

// MARK: - Glass Surface & Controls
// Translates Apple WWDC materials & depth specifications:
// - Translucent functional layers floating above content
// - Light-catching subtle borders
// - Immediate tactile feedback on interaction

public struct GlassSurface: ViewModifier {
    public var radius: CGFloat = AppRadius.xl
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(AppColors.background, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(AppColors.border, lineWidth: 1)
                )
        } else if #available(macOS 26, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: radius))
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(AppColors.borderHighlight.opacity(0.35), lineWidth: 0.8)
                )
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(.regularMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(AppColors.borderHighlight.opacity(0.4), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        }
    }
}

public extension View {
    func floatingGlass(radius: CGFloat = AppRadius.xl) -> some View {
        modifier(GlassSurface(radius: radius))
    }
}

public struct GlassGroup<Content: View>: View {
    @ViewBuilder public var content: Content
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    public var body: some View {
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: AppSpacing.lg) { content }
        } else {
            content
        }
    }
}

public struct GlassIconButton: View {
    public let title: String
    public let symbol: String
    public var action: () -> Void

    public init(title: String, symbol: String, action: @escaping () -> Void) {
        self.title = title
        self.symbol = symbol
        self.action = action
    }

    public var body: some View {
        if #available(macOS 26, *) {
            button
                .buttonStyle(.glass)
                .buttonStyle(.tactile(scale: 0.95))
        } else {
            button
                .buttonStyle(.bordered)
                .buttonStyle(.tactile(scale: 0.95))
        }
    }

    private var button: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 28, height: 28)
        }
        .controlSize(.large)
        .accessibilityLabel(title)
        .help(title)
    }
}
