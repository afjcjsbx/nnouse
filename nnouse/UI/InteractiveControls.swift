import AppKit

final class InteractiveTextField: NSTextField {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

final class InteractiveSlider: NSSlider {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

final class InteractiveStepper: NSStepper {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

final class InteractivePopUpButton: NSPopUpButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
