import SwiftUI

enum Theme {
    /// Timeprice green, brightened to read on the black notch.
    static let mint = Color(red: 0.49, green: 0.86, blue: 0.62)
    static let mintDeep = Color(red: 0.26, green: 0.41, blue: 0.31)
    static let cream = Color(red: 0.98, green: 0.976, blue: 0.965)
    static let primary = Color.white
    static let secondary = Color.white.opacity(0.58)
    static let tertiary = Color.white.opacity(0.36)
    static let hairline = Color.white.opacity(0.09)
    static let card = Color.white.opacity(0.065)

    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

private struct ExportRenderingKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True while views are rendered with `ImageRenderer`, which cannot draw
    /// AppKit-backed controls (text fields, scroll views). Views swap those for
    /// visually identical pure-SwiftUI stand-ins.
    var isExportRendering: Bool {
        get { self[ExportRenderingKey.self] }
        set { self[ExportRenderingKey.self] = newValue }
    }
}

/// The notch silhouette: concave "ears" where it meets the top of the screen,
/// rounded corners at the bottom — the same outline as the hardware notch, so the
/// pill reads as the notch growing.
struct NotchShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set {
            topRadius = newValue.first
            bottomRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let t = min(topRadius, rect.width / 4)
        let b = min(bottomRadius, (rect.width - 2 * t) / 2, rect.height - t)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(
            to: CGPoint(x: rect.minX + t, y: rect.minY + t),
            control: CGPoint(x: rect.minX + t, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + t, y: rect.maxY - b))
        p.addQuadCurve(
            to: CGPoint(x: rect.minX + t + b, y: rect.maxY),
            control: CGPoint(x: rect.minX + t, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - t - b, y: rect.maxY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX - t, y: rect.maxY - b),
            control: CGPoint(x: rect.maxX - t, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - t, y: rect.minY + t))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - t, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

/// Timeprice mark: the popup's clock glyph in a rounded tile.
struct TimepriceMark: View {
    var size: CGFloat = 18
    var body: some View {
        Image(systemName: "hourglass")
            .font(.system(size: size * 0.62, weight: .semibold))
            .foregroundStyle(Theme.mint)
            .frame(width: size, height: size)
    }
}
