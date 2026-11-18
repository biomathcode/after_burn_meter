import SwiftUI
import AppKit

// MARK: - App Design Tokens
// Designed according to Apple Human Interface Guidelines and Dieter Rams' principles:
// High contrast, purposeful restraint, fluid physical motion, adaptive light/dark vibrancy.

// MARK: - Colors
public enum AppColors {
    /// Dynamic brand teal: deeply saturated in light mode for AA/AAA contrast, luminous in dark mode
    public static let brandTeal = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.22, green: 0.78, blue: 0.70, alpha: 1.0)
            : NSColor(red: 0.07, green: 0.44, blue: 0.41, alpha: 1.0)
    }))

    /// Dynamic athletic energy orange: vibrant and legible across appearances
    public static let brandOrange = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 1.00, green: 0.52, blue: 0.26, alpha: 1.0)
            : NSColor(red: 0.82, green: 0.32, blue: 0.12, alpha: 1.0)
    }))

    /// Dynamic mint for verified / valid sensor states
    public static let brandMint = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.32, green: 0.88, blue: 0.64, alpha: 1.0)
            : NSColor(red: 0.10, green: 0.60, blue: 0.42, alpha: 1.0)
    }))

    /// Semantic text inks
    public static let ink = Color.primary
    public static let secondary = Color.secondary
    public static let tertiary = Color(nsColor: .tertiaryLabelColor)

    /// Dynamic backgrounds
    public static let background = Color(nsColor: .windowBackgroundColor)
    public static let secondaryBackground = Color(nsColor: .underPageBackgroundColor)

    /// Adaptive card surface tint
    public static let cardSurface = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(calibratedWhite: 0.18, alpha: 0.65)
            : NSColor(calibratedWhite: 1.0, alpha: 0.75)
    }))

    /// Subtle element fill for tags, chips, unselected items
    public static let subtleFill = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(calibratedWhite: 1.0, alpha: 0.07)
            : NSColor(calibratedWhite: 0.0, alpha: 0.04)
    }))

    /// Dynamic structural border stroke
    public static let border = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(calibratedWhite: 1.0, alpha: 0.11)
            : NSColor(calibratedWhite: 0.0, alpha: 0.08)
    }))

    /// Light-catching highlight border (for glass surfaces)
    public static let borderHighlight = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(calibratedWhite: 1.0, alpha: 0.18)
            : NSColor(calibratedWhite: 1.0, alpha: 0.80)
    }))

    /// Camera slate backdrop
    public static let cameraSlate = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.06, green: 0.09, blue: 0.13, alpha: 1.0)
            : NSColor(red: 0.11, green: 0.17, blue: 0.22, alpha: 1.0)
    }))
}

// MARK: - Typography Tokens
public enum AppTypography {
    /// Hero display for splash, onboarding, and focal counters
    public static let hero = Font.system(size: 34, weight: .bold, design: .rounded)
    /// Page level prominent title
    public static let pageTitle = Font.system(size: 28, weight: .semibold, design: .rounded)
    /// Section headline
    public static let sectionTitle = Font.system(size: 18, weight: .semibold, design: .rounded)
    /// Prominent card header or modal title
    public static let cardTitle = Font.system(size: 15, weight: .semibold)
    /// Standard body text
    public static let body = Font.system(size: 13, weight: .regular)
    /// Emphasized body text
    public static let bodyMedium = Font.system(size: 13, weight: .medium)
    /// Secondary callout text
    public static let callout = Font.system(size: 12, weight: .regular)
    /// Callout medium for labels
    public static let calloutMedium = Font.system(size: 12, weight: .medium)
    /// Caption and metadata
    public static let caption = Font.system(size: 11, weight: .regular)
    /// Caption bold / medium
    public static let captionMedium = Font.system(size: 11, weight: .medium)
    /// Micro metadata
    public static let micro = Font.system(size: 10, weight: .regular)
    /// Micro medium
    public static let microMedium = Font.system(size: 10, weight: .medium)

    /// Numeric metrics font with optical sizing & tabular figures
    public static func metric(size: CGFloat = 30) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }
}

// MARK: - Spacing Tokens (4pt / 8pt grid)
public enum AppSpacing {
    /// 4pt
    public static let xxs: CGFloat = 4
    /// 8pt
    public static let xs: CGFloat = 8
    /// 12pt
    public static let sm: CGFloat = 12
    /// 16pt
    public static let md: CGFloat = 16
    /// 20pt
    public static let lg: CGFloat = 20
    /// 24pt
    public static let xl: CGFloat = 24
    /// 28pt
    public static let xxl: CGFloat = 28
    /// 32pt
    public static let xxxl: CGFloat = 32
    /// 40pt
    public static let huge: CGFloat = 40
}

// MARK: - Corner Radius Tokens
public enum AppRadius {
    /// 6pt - tight chips, tags
    public static let xs: CGFloat = 6
    /// 10pt - text fields, small buttons
    public static let sm: CGFloat = 10
    /// 14pt - inner cards, list items
    public static let md: CGFloat = 14
    /// 18pt - standard panels, modal cards
    public static let lg: CGFloat = 18
    /// 24pt - floating glass bars, stage controls
    public static let xl: CGFloat = 24
    /// 28pt - large floating containers
    public static let xxl: CGFloat = 28
    /// Pill / Capsule
    public static let pill: CGFloat = 999
}

// MARK: - Animation Tokens (WWDC Designing Fluid Interfaces guidelines)
public enum AppAnimation {
    /// Critically damped UI spring (no overshoot, settles smoothly and predictably)
    public static let springDefault = Animation.spring(response: 0.35, dampingFraction: 1.0)
    /// Snappy interactive spring for touch/press and control responses
    public static let springSnappy = Animation.spring(response: 0.25, dampingFraction: 0.92)
    /// Momentum spring with slight, tasteful overshoot for gestures, sheets, completions
    public static let springMomentum = Animation.spring(response: 0.40, dampingFraction: 0.80)
    /// Smooth subtle transition for state changes
    public static let smooth = Animation.smooth(duration: 0.25)
}

// MARK: - Tactile Button Style
/// Adds instant feedback on pointer-down with scale damping per Apple design guidelines
public struct TactileButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.97
    var pressedOpacity: Double = 0.88

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1.0)
            .opacity(configuration.isPressed ? pressedOpacity : 1.0)
            .animation(AppAnimation.springSnappy, value: configuration.isPressed)
    }
}

public extension ButtonStyle where Self == TactileButtonStyle {
    static var tactile: TactileButtonStyle { TactileButtonStyle() }
    static func tactile(scale: CGFloat = 0.97, opacity: Double = 0.88) -> TactileButtonStyle {
        TactileButtonStyle(pressedScale: scale, pressedOpacity: opacity)
    }
}
