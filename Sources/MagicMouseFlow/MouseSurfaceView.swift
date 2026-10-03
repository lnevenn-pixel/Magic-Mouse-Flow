import AppKit

@MainActor
final class MouseSurfaceView: NSView {
    var touches: [TouchEngine.SurfaceTouch] = []
    var clickKind = ""
    var clickTime = Date.distantPast
    var leftButtonLocked = false
    var showsTapResponseArea = true
    var tapResponseMinY: CGFloat = 0.50
    var tapCenterDeadZoneWidth: CGFloat = 0.16

    override var isFlipped: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: 490, height: 280) }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.controlBackgroundColor.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 14, yRadius: 14).fill()

        let mouseRect = NSRect(x: bounds.midX - 92, y: 18, width: 184, height: 238)
        let mousePath = NSBezierPath(roundedRect: mouseRect, xRadius: 76, yRadius: 76)
        NSColor.windowBackgroundColor.setFill()
        mousePath.fill()

        NSGraphicsContext.saveGraphicsState()
        mousePath.addClip()
        let clickIsFresh = Date().timeIntervalSince(clickTime) < 0.32
        if leftButtonLocked || (clickIsFresh && clickKind.contains("左")) {
            NSColor.systemBlue.withAlphaComponent(leftButtonLocked ? 0.30 : 0.18).setFill()
            NSRect(x: mouseRect.minX, y: mouseRect.minY,
                   width: mouseRect.width / 2, height: mouseRect.height * 0.46).fill()
        } else if clickIsFresh && clickKind.contains("右") {
            NSColor.systemPurple.withAlphaComponent(0.22).setFill()
            NSRect(x: mouseRect.midX, y: mouseRect.minY,
                   width: mouseRect.width / 2, height: mouseRect.height * 0.46).fill()
        }
        NSGraphicsContext.restoreGraphicsState()

        if showsTapResponseArea {
            NSGraphicsContext.saveGraphicsState()
            mousePath.addClip()
            let redFill = NSColor.systemRed.withAlphaComponent(0.13)
            let redStroke = NSColor.systemRed.withAlphaComponent(0.72)

            let bottomTop = mouseRect.maxY - tapResponseMinY * mouseRect.height
            let bottomZone = NSRect(x: mouseRect.minX, y: bottomTop,
                                    width: mouseRect.width, height: mouseRect.maxY - bottomTop)
            redFill.setFill()
            bottomZone.fill()
            redStroke.setStroke()
            let bottomOutline = NSBezierPath(rect: bottomZone)
            bottomOutline.lineWidth = 1.5
            bottomOutline.stroke()

            let centerWidth = tapCenterDeadZoneWidth * mouseRect.width
            let centerZone = NSRect(x: mouseRect.midX - centerWidth / 2,
                                    y: mouseRect.minY,
                                    width: centerWidth,
                                    height: bottomTop - mouseRect.minY)
            redFill.setFill()
            centerZone.fill()
            redStroke.setStroke()
            let centerOutline = NSBezierPath(rect: centerZone)
            centerOutline.lineWidth = 1.5
            centerOutline.stroke()
            NSGraphicsContext.restoreGraphicsState()
        }

        NSColor.separatorColor.setStroke()
        mousePath.lineWidth = 2
        mousePath.stroke()
        let divider = NSBezierPath()
        divider.move(to: NSPoint(x: mouseRect.midX, y: mouseRect.minY + 8))
        divider.line(to: NSPoint(x: mouseRect.midX, y: mouseRect.minY + 70))
        divider.lineWidth = 1
        divider.stroke()

        for (index, touch) in touches.enumerated() {
            let strength = CGFloat(max(0, min(1.5, touch.intensity)))
            let radius = 10 + strength * 9
            let center = NSPoint(
                x: mouseRect.minX + CGFloat(touch.x) * mouseRect.width,
                y: mouseRect.maxY - CGFloat(touch.y) * mouseRect.height
            )
            let circle = NSBezierPath(ovalIn: NSRect(x: center.x - radius,
                                                     y: center.y - radius,
                                                     width: radius * 2,
                                                     height: radius * 2))
            NSColor.systemCyan.withAlphaComponent(0.30 + min(0.55, strength * 0.35)).setFill()
            circle.fill()
            NSColor.systemBlue.setStroke()
            circle.lineWidth = 1.5
            circle.stroke()

            let label = "\(index + 1)  \(String(format: "%.2f", touch.intensity))"
            label.draw(at: NSPoint(x: center.x + radius + 4, y: center.y - 8),
                       withAttributes: [
                        .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
                        .foregroundColor: NSColor.labelColor
                       ])
        }

        let state: String
        if leftButtonLocked { state = "左键保持按下" }
        else if clickIsFresh { state = "检测到：\(clickKind)" }
        else if touches.isEmpty { state = "等待触碰…" }
        else { state = "检测到 \(touches.count) 个触点" }
        state.draw(at: NSPoint(x: 16, y: bounds.height - 28),
                   withAttributes: [
                    .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                    .foregroundColor: leftButtonLocked ? NSColor.systemBlue : NSColor.secondaryLabelColor
                   ])
    }
}
