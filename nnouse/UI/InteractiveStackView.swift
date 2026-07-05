import AppKit

final class InteractiveStackView: NSStackView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
