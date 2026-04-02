import AppKit

/// Programmatic menubar icon for Nudgy.
/// Drawn as a template image so macOS handles dark/light mode automatically.
///
/// Design: A speech bubble silhouette with a small pointed tail at the bottom-left,
/// representing notification/communication — the core purpose of Nudgy.
enum NudgyIcon {

    /// Create the menubar icon.
    /// - Parameters:
    ///   - filled: Whether the bubble is solid-filled (active/attention) or outlined (idle).
    ///   - badge: Whether to show a small dot badge in the upper-right (needs attention).
    ///   - size: Point size of the icon (standard menubar is 18pt).
    static func menuBarIcon(filled: Bool = false, badge: Bool = false, size: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            drawBubble(in: rect, filled: filled)
            if badge {
                drawBadge(in: rect)
            }
            return true
        }
        return image
    }

    // MARK: - Drawing

    private static func drawBubble(in rect: NSRect, filled: Bool) {
        let w = rect.width
        let h = rect.height

        // Bubble body: rounded rectangle
        let bubbleRect = NSRect(
            x: w * 0.06,
            y: h * 0.28,
            width: w * 0.88,
            height: h * 0.61
        )
        let cornerRadius = w * 0.19

        let bubble = NSBezierPath(roundedRect: bubbleRect, xRadius: cornerRadius, yRadius: cornerRadius)

        // Tail: small triangle pointing down-left from the bubble bottom edge
        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: w * 0.22, y: h * 0.28))
        tail.line(to: NSPoint(x: w * 0.11, y: h * 0.06))
        tail.line(to: NSPoint(x: w * 0.39, y: h * 0.28))
        tail.close()

        bubble.append(tail)

        NSColor.black.set()

        if filled {
            bubble.fill()
        } else {
            bubble.lineWidth = w * 0.083 // ~1.5pt at 18pt size
            bubble.lineJoinStyle = .round
            bubble.stroke()
        }
    }

    private static func drawBadge(in rect: NSRect) {
        let w = rect.width
        let h = rect.height

        // Small circular badge in upper-right corner
        let badgeSize = w * 0.30
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
