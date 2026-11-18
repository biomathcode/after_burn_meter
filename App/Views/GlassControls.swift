import SwiftUI

struct GlassSurface: ViewModifier {
    var radius: CGFloat = 24
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(Palette.background, in: RoundedRectangle(cornerRadius: radius))
                .overlay(RoundedRectangle(cornerRadius: radius).stroke(.primary.opacity(0.12)))
        } else if #available(macOS 26, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: radius))
        } else {
            content.background(.regularMaterial, in: RoundedRectangle(cornerRadius: radius))
        }
    }
}

extension View {
    func floatingGlass(radius: CGFloat = 24) -> some View { modifier(GlassSurface(radius: radius)) }
}

struct GlassGroup<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        if #available(macOS 26, *) { GlassEffectContainer(spacing: 18) { content } }
        else { content }
    }
}

struct GlassIconButton: View {
    let title: String
    let symbol: String
    var action: () -> Void
    var body: some View {
        if #available(macOS 26, *) { button.buttonStyle(.glass) }
        else { button.buttonStyle(.bordered) }
    }
    private var button: some View {
        Button(action: action) { Image(systemName: symbol).frame(width: 24, height: 28) }
            .controlSize(.large).accessibilityLabel(title).help(title)
    }
}
