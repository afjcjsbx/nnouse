import AppKit
import CoreGraphics

final class AppController: NSObject {

    private var overlayWindows: [OverlayWindow] = []
    private var isOverlayVisible = false
    private var eventTap: CFMachPort?
    private var statusBar: StatusBarController?

    override init() {
        super.init()
        buildOverlays()
        installEventTap()
        statusBar = StatusBarController(appController: self)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange),
            name: Settings.didChangeNotification,
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
        // Render the windows with the new settings; if they were visible, bring them back up
        let wasVisible = isOverlayVisible
        hideOverlay()
        buildOverlays()
        if wasVisible { showOverlay() }
    }

    // MARK: - Event tap

    private func installEventTap() {
        guard AXIsProcessTrusted() else {
            print("nnouse: Accessibility permission is missing. Add it in System Preferences → Privacy & Security → Accessibility.")
            return
        }

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue | 1 << CGEventType.keyUp.rawValue)
        let selfPtr = Unmanaged.passRetained(self).toOpaque()

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
        CFRunLoopAddSource(CFRunLoopGetCurrent(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handleCGEvent(_ event: CGEvent, type: CGEventType) -> Unmanaged<CGEvent>? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        let relevantMask = CGEventFlags([.maskAlternate, .maskCommand, .maskControl, .maskShift])
        let activeModifiers = flags.intersection(relevantMask)
        let onlyCommand = activeModifiers == .maskCommand
        let arrowKeys: Set<Int64> = [123, 124, 125, 126]

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

        guard type == .keyDown else { return Unmanaged.passRetained(event) }

        // Configurable combination → toggle grid
        let activationMods = Config.activationModifiers.intersection(relevantMask)
        if activeModifiers == activationMods && keyCode == Config.activationKeyCode {
            DispatchQueue.main.async { [weak self] in self?.toggleOverlay() }
            return nil
        }

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
        NotificationCenter.default.removeObserver(self)
    }
}
