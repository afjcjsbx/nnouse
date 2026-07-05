import AppKit

final class InteractiveButton: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
