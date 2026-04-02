import AppKit

/// Programmatic menubar icon for Nudgy.
/// Drawn as a template image so macOS handles dark/light mode automatically.
///
/// Design: A solid dot in the bottom-left with sweeping curved arcs radiating
/// upward-right — a pulse/ping signal.
///
/// Coordinates translated directly from the SVG mockup (18x18 viewBox):
///   dot: cx=5 cy=13 r=2
///   arc1: M8.5,10 C9.5,9 10,7.5 10,6
///   arc2: M11.5,7.5 C13,5.5 13.5,3.5 13,1.5
///   arc3: M14.5,5 C16.5,2.5 17,0 16,-2  opacity=0.5
enum NudgyIcon {

    static func menuBarIcon(filled: Bool = false, badge: Bool = false, size: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            drawPulse(in: rect, filled: filled)
            if badge {
                drawBadge(in: rect)
            }
            return true
        }
        return image
    }

    // MARK: - Drawing

    private static func drawPulse(in rect: NSRect, filled: Bool) {
        let s = rect.width / 18.0 // scale from 18pt reference

        // Helper: convert SVG y (origin top-left) to AppKit y (origin bottom-left)
        func y(_ svgY: CGFloat) -> CGFloat { rect.height - svgY * s }
        func x(_ svgX: CGFloat) -> CGFloat { svgX * s }

        NSColor.black.set()

        // Dot — SVG: cx=5, cy=13, r=2
        let dotR = (filled ? 2.4 : 2.0) * s
        let dotRect = NSRect(
            x: x(5) - dotR, y: y(13) - dotR,
            width: dotR * 2, height: dotR * 2
        )
        NSBezierPath(ovalIn: dotRect).fill()

        let lw = (filled ? 1.5 : 1.3) * s

        // Arc 1 — SVG: M8.5,10 C9.5,9 10,7.5 10,6
        let arc1 = NSBezierPath()
        arc1.move(to: NSPoint(x: x(8.5), y: y(10)))
        arc1.curve(
            to: NSPoint(x: x(10), y: y(6)),
            controlPoint1: NSPoint(x: x(9.5), y: y(9)),
            controlPoint2: NSPoint(x: x(10), y: y(7.5))
        )
        arc1.lineWidth = lw
        arc1.lineCapStyle = .round
        NSColor.black.set()
        arc1.stroke()

        // Arc 2 — SVG: M11.5,7.5 C13,5.5 13.5,3.5 13,1.5
        let arc2 = NSBezierPath()
        arc2.move(to: NSPoint(x: x(11.5), y: y(7.5)))
        arc2.curve(
            to: NSPoint(x: x(13), y: y(1.5)),
            controlPoint1: NSPoint(x: x(13), y: y(5.5)),
            controlPoint2: NSPoint(x: x(13.5), y: y(3.5))
        )
        arc2.lineWidth = lw
        arc2.lineCapStyle = .round
        NSColor.black.set()
        arc2.stroke()

        // Arc 3 — SVG: M14.5,5 C16.5,2.5 17,0 16,-2  opacity=0.5
        let arc3 = NSBezierPath()
        arc3.move(to: NSPoint(x: x(14.5), y: y(5)))
        arc3.curve(
            to: NSPoint(x: x(16), y: y(-2)),
            controlPoint1: NSPoint(x: x(16.5), y: y(2.5)),
            controlPoint2: NSPoint(x: x(17), y: y(0))
        )
        arc3.lineWidth = lw * 0.85
        arc3.lineCapStyle = .round
        NSColor.black.withAlphaComponent(filled ? 0.6 : 0.45).set()
        arc3.stroke()
    }

    private static func drawBadge(in rect: NSRect) {
        let w = rect.width
        let h = rect.height
        let badgeSize = w * 0.28
        let badgeRect = NSRect(
            x: w - badgeSize - w * 0.02,
            y: h - badgeSize - h * 0.02,
            width: badgeSize,
            height: badgeSize
        )
        NSColor.black.setFill()
        NSBezierPath(ovalIn: badgeRect).fill()
    }
}
