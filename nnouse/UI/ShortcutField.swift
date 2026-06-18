import AppKit
import CoreGraphics

// Field that displays the current shortcut and records a new one on click
final class ShortcutField: NSControl {

    private(set) var keyCode: Int64
    private(set) var modifiers: CGEventFlags

    private let label = NSTextField(labelWithString: "")
    private var isRecording = false

    var onChange: ((Int64, CGEventFlags) -> Void)?

    init(keyCode: Int64, modifiers: CGEventFlags) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        super.init(frame: .zero)
        setup()
        updateLabel()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 4
        layer?.borderWidth = 1
        setNormalAppearance()

        label.translatesAutoresizingMaskIntoConstraints = false
        label.alignment = .center
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    private func setNormalAppearance() {
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        layer?.borderColor = NSColor.separatorColor.cgColor
        label.textColor = .labelColor
    }

    private func setRecordingAppearance() {
        layer?.backgroundColor = NSColor.selectedControlColor.cgColor
        layer?.borderColor = NSColor.controlAccentColor.cgColor
        label.textColor = .controlAccentColor
    }

    private func updateLabel() {
        label.stringValue = isRecording
            ? "Press shortcut…"
            : ShortcutField.displayString(keyCode: keyCode, modifiers: modifiers)
    }

    // MARK: - Mouse / Focus

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        if isRecording {
            stopRecording(save: false)
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        setRecordingAppearance()
        updateLabel()
        window?.makeFirstResponder(self)
    }

    private func stopRecording(save: Bool) {
        isRecording = false
        setNormalAppearance()
        updateLabel()
        if !save { window?.makeFirstResponder(nil) }
    }

    // MARK: - Key capture

    override func keyDown(with event: NSEvent) {
        guard isRecording else { super.keyDown(with: event); return }

        // Ignore modifier-only keys
        let code = Int64(event.keyCode)
        let modifierOnlyCodes: Set<Int64> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
        guard !modifierOnlyCodes.contains(code) else { return }

        // Esc without modifiers = cancel
        if code == 53 && event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty {
            stopRecording(save: false)
            return
        }

        let nsFlags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        var cgFlags = CGEventFlags()
        if nsFlags.contains(.option)  { cgFlags.insert(.maskAlternate) }
        if nsFlags.contains(.command) { cgFlags.insert(.maskCommand) }
        if nsFlags.contains(.control) { cgFlags.insert(.maskControl) }
        if nsFlags.contains(.shift)   { cgFlags.insert(.maskShift) }

        keyCode = code
        modifiers = cgFlags
        onChange?(keyCode, modifiers)
        stopRecording(save: true)
    }

    override func resignFirstResponder() -> Bool {
        if isRecording { stopRecording(save: false) }
        return super.resignFirstResponder()
    }

    // MARK: - Display

    static func displayString(keyCode: Int64, modifiers: CGEventFlags) -> String {
        var parts = ""
        if modifiers.contains(.maskControl)   { parts += "⌃" }
        if modifiers.contains(.maskAlternate) { parts += "⌥" }
        if modifiers.contains(.maskShift)     { parts += "⇧" }
        if modifiers.contains(.maskCommand)   { parts += "⌘" }
        parts += keyName(for: keyCode)
        return parts
    }

    private static func keyName(for keyCode: Int64) -> String {
        switch keyCode {
        case 49: return "Space"
        case 36: return "↩"
        case 51: return "⌫"
        case 53: return "Esc"
        case 48: return "⇥"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default:
            let ch = KeyMap.char(for: keyCode)
            return ch.isEmpty ? "(\(keyCode))" : ch.uppercased()
        }
    }
}
