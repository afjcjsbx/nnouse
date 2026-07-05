import AppKit
import CoreGraphics

func performClick(at point: CGPoint) {
    CGWarpMouseCursorPosition(point)
    CGAssociateMouseAndMouseCursorPosition(1)
    let src = CGEventSource(stateID: .hidSystemState)
    let down = CGEvent(mouseEventSource: src, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
    let up   = CGEvent(mouseEventSource: src, mouseType: .leftMouseUp,   mouseCursorPosition: point, mouseButton: .left)
    down?.post(tap: .cghidEventTap)
    up?.post(tap: .cghidEventTap)
}
