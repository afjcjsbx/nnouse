import AppKit
import Carbon
import CoreGraphics

final class AppController: NSObject {

    private var overlayWindows: [OverlayWindow] = []
    private var isOverlayVisible = false
    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?
    private var activationHotKey: EventHotKeyRef?
    private var activationHotKeyHandler: EventHandlerRef?
    private var activationUsesEventTapFallback = false
    private var suppressedActivationKeyCode: Int64?
    private var statusBar: StatusBarController?
    private var hasRequestedAccessibilityPrompt = false
    private var hasLoggedMissingAccessibility = false

    private let activationHotKeySignature: OSType = 0x6E6E6F75 // "nnou"
    private let activationHotKeyIdentifier: UInt32 = 1

    override init() {
        super.init()
        buildOverlays()
        updateActivationHotKey()
        ensureEventTap(promptForAccessibility: true)
        statusBar = StatusBarController(appController: self)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange),
            name: Settings.didChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(shortcutRecordingDidChange),
            name: ShortcutRecordingState.didChangeNotification,
            object: nil
        )
    }

    // MARK: - Overlay lifecycle

    private func buildOverlays() {
        overlayWindows.forEach { $0.orderOut(nil) }
        overlayWindows = NSScreen.screens.map {
            OverlayWindow(screen: $0, cols: Config.columns, rows: Config.rows)
        }
    }

    private func showOverlay() {
        // Rebuild only if the number of screens has changed
        if overlayWindows.count != NSScreen.screens.count {
            buildOverlays()
        }
        overlayWindows.forEach { $0.reset(); $0.orderFrontRegardless() }
        isOverlayVisible = true
    }

    private func hideOverlay() {
        overlayWindows.forEach { $0.dismiss() }
        isOverlayVisible = false
    }

    @objc func toggleOverlay() {
        isOverlayVisible ? hideOverlay() : showOverlay()
    }

    @objc private func settingsDidChange() {
        MouseMover.shared.updateFPS(Config.mouseFPS)
        updateActivationHotKey()
        ensureEventTap()
        // Render the windows with the new settings; if they were visible, bring them back up
        let wasVisible = isOverlayVisible
        hideOverlay()
        buildOverlays()
        if wasVisible { showOverlay() }
    }

    @objc private func appDidBecomeActive() {
        ensureEventTap()
    }

    @objc private func shortcutRecordingDidChange() {
        suppressedActivationKeyCode = nil
        if ShortcutRecordingState.isRecording {
            unregisterActivationHotKey()
        } else {
            updateActivationHotKey()
        }
    }

    // MARK: - Activation hotkey

    private func updateActivationHotKey() {
        ensureActivationHotKeyHandler()
        unregisterActivationHotKey()

        let hotKeyID = EventHotKeyID(
            signature: activationHotKeySignature,
            id: activationHotKeyIdentifier
        )
        let status = RegisterEventHotKey(
            UInt32(Config.activationKeyCode),
            carbonModifiers(from: Config.activationModifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &activationHotKey
        )

        activationUsesEventTapFallback = status != noErr
        if status != noErr {
            print("nnouse: Activation shortcut is using event-tap fallback (status \(status)).")
        }
    }

    private func unregisterActivationHotKey() {
        if let activationHotKey {
            UnregisterEventHotKey(activationHotKey)
            self.activationHotKey = nil
        }
    }

    private func ensureActivationHotKeyHandler() {
        guard activationHotKeyHandler == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = Unmanaged.passUnretained(self).toOpaque()

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }

                let controller = Unmanaged<AppController>.fromOpaque(userData).takeUnretainedValue()
                guard !ShortcutRecordingState.isRecording else { return noErr }

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr else { return status }

                if hotKeyID.signature == controller.activationHotKeySignature,
                   hotKeyID.id == controller.activationHotKeyIdentifier {
                    controller.toggleOverlay()
                }
                return noErr
            },
            1,
            &eventType,
            userData,
            &activationHotKeyHandler
        )

        if status != noErr {
            print("nnouse: Could not install activation shortcut handler (status \(status)).")
        }
    }

    private func carbonModifiers(from flags: CGEventFlags) -> UInt32 {
        let relevantMask = flags.intersection([.maskAlternate, .maskCommand, .maskControl, .maskShift])
        var modifiers: UInt32 = 0

        if relevantMask.contains(.maskCommand) { modifiers |= UInt32(cmdKey) }
        if relevantMask.contains(.maskAlternate) { modifiers |= UInt32(optionKey) }
        if relevantMask.contains(.maskControl) { modifiers |= UInt32(controlKey) }
        if relevantMask.contains(.maskShift) { modifiers |= UInt32(shiftKey) }

        return modifiers
    }

    // MARK: - Event tap

    private func ensureEventTap(promptForAccessibility: Bool = false) {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: true)
            return
        }

        guard isAccessibilityTrusted(prompt: promptForAccessibility) else {
            if !hasLoggedMissingAccessibility {
                print("nnouse: Accessibility permission is missing. Grant it in System Settings → Privacy & Security → Accessibility, then return to the app.")
                hasLoggedMissingAccessibility = true
            }
            return
        }
        hasLoggedMissingAccessibility = false

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue | 1 << CGEventType.keyUp.rawValue)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo -> Unmanaged<CGEvent>? in
                guard let userInfo else { return Unmanaged.passRetained(event) }
                let ctrl = Unmanaged<AppController>.fromOpaque(userInfo).takeUnretainedValue()
                return ctrl.handleCGEvent(event, type: type)
            },
            userInfo: selfPtr
        )

        guard let tap = eventTap else {
            print("nnouse: CGEventTap has not been created.")
            return
        }

        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        eventTapSource = src
        CFRunLoopAddSource(CFRunLoopGetCurrent(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func isAccessibilityTrusted(prompt: Bool) -> Bool {
        guard prompt, !hasRequestedAccessibilityPrompt else {
            return AXIsProcessTrusted()
        }

        hasRequestedAccessibilityPrompt = true
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private func handleCGEvent(_ event: CGEvent, type: CGEventType) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        let relevantMask = CGEventFlags([.maskAlternate, .maskCommand, .maskControl, .maskShift])
        let activeModifiers = flags.intersection(relevantMask)
        let onlyCommand = activeModifiers == .maskCommand
        let arrowKeys: Set<Int64> = [123, 124, 125, 126]

        // While recording the activation shortcut, capture the raw combo from the event tap
        // through a dedicated temporary event tap owned by the shortcut field.
        if ShortcutRecordingState.isRecording {
            return Unmanaged.passRetained(event)
        }

        // ⌘ + arrow keys → continuous cursor movement
        if arrowKeys.contains(keyCode) {
            if onlyCommand {
                DispatchQueue.main.async {
                    type == .keyDown ? MouseMover.shared.keyDown(keyCode) : MouseMover.shared.keyUp(keyCode)
                }
                return nil
            } else if type == .keyUp {
                DispatchQueue.main.async { MouseMover.shared.keyUp(keyCode) }
            }
        }

        let activationMods = Config.activationModifiers.intersection(relevantMask)
        if activationUsesEventTapFallback, keyCode == Config.activationKeyCode {
            if type == .keyDown, activeModifiers == activationMods {
                suppressedActivationKeyCode = keyCode
                DispatchQueue.main.async { [weak self] in self?.toggleOverlay() }
                return nil
            }

            if type == .keyUp, suppressedActivationKeyCode == keyCode {
                suppressedActivationKeyCode = nil
                return nil
            }
        } else if type == .keyUp, suppressedActivationKeyCode == keyCode {
            suppressedActivationKeyCode = nil
        }

        guard type == .keyDown else { return Unmanaged.passRetained(event) }

        guard isOverlayVisible else { return Unmanaged.passRetained(event) }

        let ch = KeyMap.char(for: keyCode)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.overlayWindows.forEach { $0.handleKey(ch) }
            if self.overlayWindows.first?.isVisible == false {
                self.isOverlayVisible = false
            }
        }
        return nil
    }

    deinit {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let src = eventTapSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), src, .commonModes)
        }
        unregisterActivationHotKey()
        if let activationHotKeyHandler {
            RemoveEventHandler(activationHotKeyHandler)
        }
        NotificationCenter.default.removeObserver(self)
    }
}
