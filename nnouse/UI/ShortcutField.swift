import AppKit
import CoreGraphics

enum ShortcutRecordingState {
    private static let lock = NSLock()
    private static var value = false
    static let didChangeNotification = Notification.Name("nnouse.shortcutRecordingDidChange")

    static var isRecording: Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    static func set(_ newValue: Bool) {
        lock.lock()
        let didChange = value != newValue
        value = newValue
        lock.unlock()

        if didChange {
            NotificationCenter.default.post(name: didChangeNotification, object: nil)
        }
    }
}

// Field that displays the current shortcut and records a new one on click
final class ShortcutField: NSControl {

    private(set) var keyCode: Int64
    private(set) var modifiers: CGEventFlags

    private let label = NSTextField(labelWithString: "")
    private var isRecording = false
    private var recordingEventTap: CFMachPort?
    private var recordingEventTapSource: CFRunLoopSource?

    var onChange: ((Int64, CGEventFlags) -> Void)?
    var isRecordingShortcut: Bool { isRecording }

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

    func setShortcut(keyCode: Int64, modifiers: CGEventFlags) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        updateLabel()
    }

    // MARK: - Mouse / Focus

    override var acceptsFirstResponder: Bool { true }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        if isRecording {
            stopRecording(save: false)
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        ShortcutRecordingState.set(true)
        setRecordingAppearance()
        updateLabel()
        installRecordingEventTap()
        window?.makeFirstResponder(self)
    }

    private func stopRecording(save: Bool) {
        removeRecordingEventTap()
        isRecording = false
        ShortcutRecordingState.set(false)
        setNormalAppearance()
        updateLabel()
        if !save { window?.makeFirstResponder(nil) }
    }

    // MARK: - Key capture

    override func keyDown(with event: NSEvent) {
        guard isRecording else { super.keyDown(with: event); return }

        // Ignore modifier-only keys
        let code = Int64(event.keyCode)
        guard !Self.isModifierOnlyKey(code) else { return }

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

        finishRecording(with: code, modifiers: cgFlags)
    }

    override func resignFirstResponder() -> Bool {
        if isRecording { stopRecording(save: false) }
        return super.resignFirstResponder()
    }

    private func installRecordingEventTap() {
        guard recordingEventTap == nil else {
            if let recordingEventTap {
                CGEvent.tapEnable(tap: recordingEventTap, enable: true)
            }
            return
        }

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue | 1 << CGEventType.keyUp.rawValue)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        recordingEventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passRetained(event) }
                let field = Unmanaged<ShortcutField>.fromOpaque(userInfo).takeUnretainedValue()
                return field.handleRecordingEvent(event, type: type)
            },
            userInfo: selfPtr
        )

        guard let recordingEventTap else { return }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, recordingEventTap, 0)
        recordingEventTapSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: recordingEventTap, enable: true)
    }

    private func removeRecordingEventTap() {
        if let source = recordingEventTapSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            recordingEventTapSource = nil
        }

        if let recordingEventTap {
            CFMachPortInvalidate(recordingEventTap)
            self.recordingEventTap = nil
        }
    }

    private func handleRecordingEvent(_ event: CGEvent, type: CGEventType) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let recordingEventTap {
                CGEvent.tapEnable(tap: recordingEventTap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        guard isRecording else { return Unmanaged.passRetained(event) }
        guard type == .keyDown else { return Unmanaged.passRetained(event) }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard !Self.isModifierOnlyKey(keyCode) else { return Unmanaged.passRetained(event) }

        let relevantMask = CGEventFlags([.maskAlternate, .maskCommand, .maskControl, .maskShift])
        let activeModifiers = event.flags.intersection(relevantMask)

        if keyCode == 53 && activeModifiers.isEmpty {
            DispatchQueue.main.async { [weak self] in
                self?.stopRecording(save: false)
            }
            return nil
        }

        DispatchQueue.main.async { [weak self] in
            self?.finishRecording(with: keyCode, modifiers: activeModifiers)
        }
        return nil
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

    static func isModifierOnlyKey(_ keyCode: Int64) -> Bool {
        let modifierOnlyCodes: Set<Int64> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
        return modifierOnlyCodes.contains(keyCode)
    }

    private func finishRecording(with keyCode: Int64, modifiers: CGEventFlags) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        onChange?(keyCode, modifiers)
        stopRecording(save: true)
    }
}
