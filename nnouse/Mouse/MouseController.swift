import AppKit
import CoreGraphics

// MARK: - Synthetic click

func performClick(at point: CGPoint) {
    CGWarpMouseCursorPosition(point)
    CGAssociateMouseAndMouseCursorPosition(1)
    let src = CGEventSource(stateID: .hidSystemState)
    let down = CGEvent(mouseEventSource: src, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
    let up   = CGEvent(mouseEventSource: src, mouseType: .leftMouseUp,   mouseCursorPosition: point, mouseButton: .left)
    down?.post(tap: .cghidEventTap)
    up?.post(tap: .cghidEventTap)
}

// MARK: - Continuous cursor movement with arrow keys

final class MouseMover {

    static let shared = MouseMover()

    private var timer: Timer?
    private var dx: CGFloat = 0
    private var dy: CGFloat = 0
    private var activeKeys: Set<Int64> = []
    private var fps: Double = 120

    func updateFPS(_ newFPS: Int) {
        fps = Double(newFPS)
        if timer != nil {
            stopTimer()
            startTimer()
        }
    }

    func keyDown(_ keyCode: Int64) {
        activeKeys.insert(keyCode)
        updateDirection()
        if timer == nil { startTimer() }
    }

    func keyUp(_ keyCode: Int64) {
        activeKeys.remove(keyCode)
        updateDirection()
        if activeKeys.isEmpty { stopTimer() }
    }

    private func updateDirection() {
        dx = 0; dy = 0
        if activeKeys.contains(123) { dx -= 1 }  // ←
        if activeKeys.contains(124) { dx += 1 }  // →
        if activeKeys.contains(126) { dy -= 1 }  // ↑
        if activeKeys.contains(125) { dy += 1 }  // ↓
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / fps, repeats: true) { [weak self] _ in
            guard let self, self.dx != 0 || self.dy != 0 else { return }
            let current = NSEvent.mouseLocation
            let primaryH = NSScreen.screens[0].frame.height
            let pos = CGPoint(x: current.x + self.dx, y: primaryH - current.y + self.dy)
            CGWarpMouseCursorPosition(pos)
            CGAssociateMouseAndMouseCursorPosition(1)
        }
        RunLoop.current.add(timer!, forMode: .common)
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
