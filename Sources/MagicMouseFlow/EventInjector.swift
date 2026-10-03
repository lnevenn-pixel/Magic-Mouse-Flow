import AppKit
import ApplicationServices

enum EventInjector {
    private static let gestureType = CGEventType(rawValue: 29)!
    private static let gestureKindField = CGEventField(rawValue: 110)!
    private static let magnificationField = CGEventField(rawValue: 113)!
    private static let gesturePhaseField = CGEventField(rawValue: 132)!

    static func click(button: CGMouseButton, count: Int = 1) {
        let point = NSEvent.mouseLocation.flippedToQuartz
        let downType: CGEventType = button == .right ? .rightMouseDown : .leftMouseDown
        let upType: CGEventType = button == .right ? .rightMouseUp : .leftMouseUp
        guard let down = CGEvent(mouseEventSource: nil, mouseType: downType, mouseCursorPosition: point, mouseButton: button),
              let up = CGEvent(mouseEventSource: nil, mouseType: upType, mouseCursorPosition: point, mouseButton: button) else { return }
        down.setIntegerValueField(.mouseEventClickState, value: Int64(count))
        up.setIntegerValueField(.mouseEventClickState, value: Int64(count))
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    static func leftMouseDown() {
        CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown,
                mouseCursorPosition: NSEvent.mouseLocation.flippedToQuartz,
                mouseButton: .left)?.post(tap: .cghidEventTap)
    }

    static func leftMouseUp() {
        CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp,
                mouseCursorPosition: NSEvent.mouseLocation.flippedToQuartz,
                mouseButton: .left)?.post(tap: .cghidEventTap)
    }

    static func beginZoom() { postMagnification(0, phase: 1) }
    static func changeZoom(delta: Double) { postMagnification(delta, phase: 2) }
    static func endZoom() { postMagnification(0, phase: 4) }

    private static func postMagnification(_ magnification: Double, phase: Int64) {
        guard let event = CGEvent(source: nil) else { return }
        event.type = gestureType
        event.setIntegerValueField(gestureKindField, value: 8)
        event.setIntegerValueField(gesturePhaseField, value: phase)
        event.setDoubleValueField(magnificationField, value: magnification)
        event.post(tap: .cghidEventTap)
    }
}

private extension CGPoint {
    static var mainScreenHeight: CGFloat { NSScreen.screens.map(\.frame.maxY).max() ?? 0 }
}

private extension NSPoint {
    var flippedToQuartz: CGPoint { CGPoint(x: x, y: CGPoint.mainScreenHeight - y) }
}
