import SwiftUI

// MARK: - Camera Guide Silhouette Overlay
// Complies with SmartSpectra SDK framing requirements and Health Icons rounded silhouette design:
// 1. Inspired by Health Icons (https://healthicons.org) rounded outline person aesthetic.
// 2. Transparent fill with an alpha stroke outline (Color.white.opacity(0.35) or mint on lock).
// 3. Face centered horizontally and vertically in the upper third (avoiding kFaceNotCentered).
// 4. Upper chest and torso visible for respiratory excursion (avoiding kChestNotVisible).
// 5. Zero impact on camera frame rate: pure lightweight Shape path, no raster blurs.

public struct CameraGuideSilhouette: View {
    public var isValid: Bool
    public var isStableMeasuring: Bool
    public var hint: String

    public init(isValid: Bool, isStableMeasuring: Bool, hint: String) {
        self.isValid = isValid
        self.isStableMeasuring = isStableMeasuring
        self.hint = hint
    }

    public var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height
            let strokeColor = isValid
                ? (isStableMeasuring ? AppColors.brandMint.opacity(0.55) : AppColors.brandMint.opacity(0.75))
                : Color.white.opacity(0.35)

            ZStack {
                // Smooth Rounded Vector Silhouette Outline (Health Icons aesthetic, transparent with alpha)
                SilhouettePath()
                    .stroke(
                        strokeColor,
                        style: StrokeStyle(
                            lineWidth: isStableMeasuring ? 1.6 : 2.0,
                            lineCap: .round,
                            lineJoin: .round,
                            dash: isStableMeasuring ? [6, 4] : []
                        )
                    )
                    .frame(width: w, height: h)

                // Eye-Level alignment crosshairs
                HeadGuides(isValid: isValid)
                    .frame(width: w, height: h)

                // SDK Guidance Badge at top with Health Icons person symbol
                VStack(spacing: AppSpacing.xxs) {
                    HStack(spacing: AppSpacing.xs) {
                        HealthIconView("person", size: 13, color: isValid ? AppColors.brandMint : Color.white.opacity(0.85))

                        Text(statusTitle)
                            .font(AppTypography.captionMedium)
                            .foregroundStyle(Color.white)
                    }
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, AppSpacing.xxs + 1)
                    .background(Color.black.opacity(0.65), in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(isValid ? AppColors.brandMint.opacity(0.5) : Color.white.opacity(0.2), lineWidth: 1)
                    )

                    if !isStableMeasuring {
                        Text(hint.isEmpty ? "Align head and chest in the guide · Even light" : hint)
                            .font(AppTypography.micro)
                            .foregroundStyle(Color.white.opacity(0.85))
                            .padding(.horizontal, AppSpacing.xs)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.5), in: RoundedRectangle(cornerRadius: AppRadius.xs, style: .continuous))
                            .lineLimit(1)
                    }
                }
                .position(x: w / 2.0, y: h * 0.16)
            }
        }
        .allowsHitTesting(false)
    }

    private var statusTitle: String {
        if isStableMeasuring {
            return "Measuring · Hold Steady"
        } else if isValid {
            return "Position Confirmed"
        } else {
            return "Face & Chest Guide"
        }
    }
}

// MARK: - Smooth Rounded Silhouette Vector Shape (Health Icons Style)
// Perfectly rounded head oval, soft continuous organic curves for shoulders and chest.
private struct SilhouettePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let cx = w / 2.0

        let scale = min(max(0.75, w / 900.0), max(0.75, h / 700.0))

        // Head Dimensions (Rounded upper oval)
        let headWidth = 150.0 * scale
        let headHeight = 188.0 * scale
        let headCenterY = h * 0.36
        let headTop = headCenterY - headHeight / 2.0

        // Rounded Head
        let headRect = CGRect(x: cx - headWidth / 2.0, y: headTop, width: headWidth, height: headHeight)
        path.addEllipse(in: headRect)

        // Neck
        let neckWidth = 66.0 * scale
        let neckTop = headTop + headHeight * 0.90
        let neckBottom = neckTop + 34.0 * scale

        // Shoulders & Chest (Soft rounded curve)
        let shoulderSpan = 390.0 * scale
        let shoulderDrop = neckBottom + 58.0 * scale
        let chestBottom = min(h * 0.94, neckBottom + 230.0 * scale)
        let torsoSpan = 430.0 * scale

        // Left side: smooth continuous bezier curve
        path.move(to: CGPoint(x: cx - neckWidth / 2.0, y: neckTop))
        path.addLine(to: CGPoint(x: cx - neckWidth / 2.0, y: neckBottom))
        path.addCurve(
            to: CGPoint(x: cx - shoulderSpan / 2.0, y: shoulderDrop),
            control1: CGPoint(x: cx - neckWidth / 2.0 - 20 * scale, y: neckBottom + 24 * scale),
            control2: CGPoint(x: cx - shoulderSpan * 0.40, y: shoulderDrop - 16 * scale)
        )
        path.addCurve(
            to: CGPoint(x: cx - torsoSpan / 2.0, y: chestBottom),
            control1: CGPoint(x: cx - shoulderSpan / 2.0 - 15 * scale, y: shoulderDrop + 55 * scale),
            control2: CGPoint(x: cx - torsoSpan / 2.0 + 8 * scale, y: chestBottom - 45 * scale)
        )

        // Right side: symmetrical smooth continuous bezier curve
        path.move(to: CGPoint(x: cx + neckWidth / 2.0, y: neckTop))
        path.addLine(to: CGPoint(x: cx + neckWidth / 2.0, y: neckBottom))
        path.addCurve(
            to: CGPoint(x: cx + shoulderSpan / 2.0, y: shoulderDrop),
            control1: CGPoint(x: cx + neckWidth / 2.0 + 20 * scale, y: neckBottom + 24 * scale),
            control2: CGPoint(x: cx + shoulderSpan * 0.40, y: shoulderDrop - 16 * scale)
        )
        path.addCurve(
            to: CGPoint(x: cx + torsoSpan / 2.0, y: chestBottom),
            control1: CGPoint(x: cx + shoulderSpan / 2.0 + 15 * scale, y: shoulderDrop + 55 * scale),
            control2: CGPoint(x: cx + torsoSpan / 2.0 - 8 * scale, y: chestBottom - 45 * scale)
        )

        return path
    }
}

// MARK: - Eye-Level Alignment Guides
private struct HeadGuides: View {
    let isValid: Bool

    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height
            let cx = w / 2.0
            let scale = min(max(0.75, w / 900.0), max(0.75, h / 700.0))
            let headCenterY = h * 0.36
            let guideColor = isValid ? AppColors.brandMint.opacity(0.35) : Color.white.opacity(0.20)

            Path { p in
                let eyeY = headCenterY - 14.0 * scale
                let tickLen = 16.0 * scale
                let halfHeadW = (150.0 * scale) / 2.0

                // Left tick
                p.move(to: CGPoint(x: cx - halfHeadW - tickLen, y: eyeY))
                p.addLine(to: CGPoint(x: cx - halfHeadW + 4, y: eyeY))

                // Right tick
                p.move(to: CGPoint(x: cx + halfHeadW - 4, y: eyeY))
                p.addLine(to: CGPoint(x: cx + halfHeadW + tickLen, y: eyeY))

                // Center vertical alignment axis
                p.move(to: CGPoint(x: cx, y: headCenterY - (188.0 * scale) / 2.0 - 10))
                p.addLine(to: CGPoint(x: cx, y: headCenterY - (188.0 * scale) / 2.0 + 10))
            }
            .stroke(guideColor, style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
        }
    }
}
