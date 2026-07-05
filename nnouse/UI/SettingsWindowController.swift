import AppKit
import CoreGraphics

final class SettingsWindowController: NSWindowController, NSWindowDelegate {

    static let shared = SettingsWindowController()

    private weak var permissionStatusLabel: NSTextField?
    private weak var columnsField: NSTextField?
    private weak var columnsStepper: NSStepper?
    private weak var rowsField: NSTextField?
    private weak var rowsStepper: NSStepper?
    private weak var gridOpacitySlider: NSSlider?
    private weak var gridOpacityValueLabel: NSTextField?
    private weak var highlightOpacitySlider: NSSlider?
    private weak var highlightOpacityValueLabel: NSTextField?
    private weak var charsetModePopup: NSPopUpButton?
    private var shortcutField: ShortcutField?
    var isRecordingShortcut: Bool { shortcutField?.isRecordingShortcut ?? false }

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 412),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "nnouse — Settings"
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        window.contentView = buildContentView()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    required init?(coder: NSCoder) { fatalError() }

    func showAndFocus() {
        refreshFromSettings()
        NSApp.setActivationPolicy(.regular)
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.orderFrontRegardless()
        window?.makeMain()
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(window?.contentView)
    }

    // MARK: - Layout

    private func buildContentView() -> NSView {
        let s = Settings.shared
        let root = InteractiveContentView(frame: NSRect(x: 0, y: 0, width: 420, height: 412))

        let stack = InteractiveStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        let colField = intField(value: s.columns, tag: 0)
        let colStepper = stepper(value: s.columns, min: 4, max: 40, tag: 0)
        columnsField = colField
        columnsStepper = colStepper

        let rowField = intField(value: s.rows, tag: 1)
        let rowStepper = stepper(value: s.rows, min: 4, max: 50, tag: 1)
        rowsField = rowField
        rowsStepper = rowStepper

        let opSlider = slider(value: s.gridOpacity, tag: 2)
        let opValue = valueLabel(String(format: "%.0f%%", s.gridOpacity * 100))
        gridOpacitySlider = opSlider
        gridOpacityValueLabel = opValue

        let hlSlider = slider(value: s.highlightOpacity, tag: 5)
        let hlValue = valueLabel(String(format: "%.0f%%", s.highlightOpacity * 100))
        highlightOpacitySlider = hlSlider
        highlightOpacityValueLabel = hlValue

        let modePopup = InteractivePopUpButton()
        for mode in Settings.CharsetMode.allCases { modePopup.addItem(withTitle: mode.label) }
        modePopup.selectItem(at: s.charsetMode.rawValue)
        modePopup.translatesAutoresizingMaskIntoConstraints = false
        modePopup.widthAnchor.constraint(equalToConstant: 190).isActive = true
        charsetModePopup = modePopup

        let sf = ShortcutField(keyCode: s.activationKeyCode, modifiers: s.activationModifiers)
        sf.onChange = { [weak self] _, _ in _ = self } // value read in applyTapped
        sf.translatesAutoresizingMaskIntoConstraints = false
        sf.widthAnchor.constraint(equalToConstant: 190).isActive = true
        sf.heightAnchor.constraint(equalToConstant: 30).isActive = true
        shortcutField = sf

        let permissionLabel = statusLabel()
        permissionStatusLabel = permissionLabel

        let applyBtn = InteractiveButton(title: "Apply", target: self, action: #selector(applyTapped))
        applyBtn.translatesAutoresizingMaskIntoConstraints = false
        applyBtn.bezelStyle = .rounded
        applyBtn.keyEquivalent = "\r"
        stack.addArrangedSubview(row(label: "Columns", control: pairStack(views: [colField, colStepper])))
        stack.addArrangedSubview(row(label: "Lines", control: pairStack(views: [rowField, rowStepper])))
        stack.addArrangedSubview(row(label: "Grid Opacity", control: opSlider, accessory: opValue))
        stack.addArrangedSubview(row(label: "Highlight Opacity", control: hlSlider, accessory: hlValue))
        stack.addArrangedSubview(row(label: "Cell Label Order", control: modePopup))
        stack.addArrangedSubview(row(label: "Activation Shortcut", control: sf))

        root.addSubview(stack)
        root.addSubview(permissionLabel)
        root.addSubview(applyBtn)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 20),

            applyBtn.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 20),
            applyBtn.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20),
            applyBtn.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -16),

            permissionLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),
            permissionLabel.trailingAnchor.constraint(lessThanOrEqualTo: applyBtn.leadingAnchor, constant: -12),
            permissionLabel.centerYAnchor.constraint(equalTo: applyBtn.centerYAnchor),
        ])

        [colField, colStepper, rowField, rowStepper].forEach {
            ($0 as? NSTextField)?.delegate = self
            ($0 as? NSStepper)?.target = self
            ($0 as? NSStepper)?.action = #selector(stepperChanged(_:))
        }

        return root
    }

    // MARK: - Factories

    private func row(label text: String, control: NSView, accessory: NSView? = nil) -> NSStackView {
        let labelField = label(text)
        labelField.widthAnchor.constraint(equalToConstant: 150).isActive = true

        let row = InteractiveStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        row.addArrangedSubview(labelField)
        row.addArrangedSubview(control)
        if let accessory {
            row.addArrangedSubview(accessory)
        }
        row.addArrangedSubview(spacerView())
        return row
    }

    private func label(_ text: String) -> NSTextField {
        let f = NSTextField(labelWithString: text)
        f.alignment = .right
        f.translatesAutoresizingMaskIntoConstraints = false
        return f
    }

    private func valueLabel(_ text: String) -> NSTextField {
        let f = NSTextField(labelWithString: text)
        f.textColor = .secondaryLabelColor
        f.translatesAutoresizingMaskIntoConstraints = false
        f.widthAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
        return f
    }

    private func statusLabel() -> NSTextField {
        let f = NSTextField(labelWithString: "")
        f.translatesAutoresizingMaskIntoConstraints = false
        f.lineBreakMode = .byTruncatingTail
        f.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return f
    }

    private func spacerView() -> NSView {
        let v = NSView(frame: .zero)
        v.translatesAutoresizingMaskIntoConstraints = false
        v.setContentHuggingPriority(.defaultLow, for: .horizontal)
        v.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return v
    }

    private func intField(value: Int, tag: Int) -> NSTextField {
        let f = InteractiveTextField()
        f.stringValue = "\(value)"
        f.tag = tag
        f.formatter = intFormatter(min: 1, max: 999)
        f.translatesAutoresizingMaskIntoConstraints = false
        f.widthAnchor.constraint(equalToConstant: 84).isActive = true
        return f
    }

    private func stepper(value: Int, min: Int, max: Int, tag: Int) -> NSStepper {
        let s = InteractiveStepper()
        s.integerValue = value
        s.minValue = Double(min)
        s.maxValue = Double(max)
        s.increment = 1
        s.tag = tag
        s.translatesAutoresizingMaskIntoConstraints = false
        s.widthAnchor.constraint(equalToConstant: 24).isActive = true
        return s
    }

    private func slider(value: CGFloat, tag: Int) -> NSSlider {
        let slider = InteractiveSlider(value: Double(value), minValue: 0.05, maxValue: 1.0, target: self, action: #selector(sliderChanged(_:)))
        slider.tag = tag
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.widthAnchor.constraint(equalToConstant: 190).isActive = true
        return slider
    }

    private func pairStack(views: [NSView]) -> NSStackView {
        let stack = InteractiveStackView()
        views.forEach { stack.addArrangedSubview($0) }
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    private func intFormatter(min: Int, max: Int) -> NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .none
        f.minimum = NSNumber(value: min)
        f.maximum = NSNumber(value: max)
        return f
    }

    // MARK: - Actions

    @objc private func stepperChanged(_ sender: NSStepper) {
        guard let field = fieldWithTag(sender.tag) else { return }
        field.integerValue = sender.integerValue
    }

    @objc private func sliderChanged(_ sender: NSSlider) {
        updateSliderLabels()
    }

    @objc private func applyTapped() {
        window?.makeFirstResponder(nil)

        let s = Settings.shared
        if let col = columnsField?.integerValue { s.columns = col }
        if let row = rowsField?.integerValue { s.rows = row }
        if let slider = gridOpacitySlider {
            s.gridOpacity = CGFloat(slider.doubleValue)
        }
        if let slider = highlightOpacitySlider {
            s.highlightOpacity = CGFloat(slider.doubleValue)
        }
        if let popup = charsetModePopup,
           let mode = Settings.CharsetMode(rawValue: popup.indexOfSelectedItem) {
            s.charsetMode = mode
        }
        if let sf = shortcutField {
            s.activationKeyCode = sf.keyCode
            s.activationModifiers = sf.modifiers
        }
        window?.close()
    }

    // MARK: - Helpers

    private func fieldWithTag(_ tag: Int) -> NSTextField? {
        switch tag {
        case 0:
            return columnsField
        case 1:
            return rowsField
        default:
            return nil
        }
    }

    private func updateSliderLabels() {
        gridOpacityValueLabel?.stringValue = String(format: "%.0f%%", (gridOpacitySlider?.doubleValue ?? 0) * 100)
        highlightOpacityValueLabel?.stringValue = String(format: "%.0f%%", (highlightOpacitySlider?.doubleValue ?? 0) * 100)
    }

    private func refreshFromSettings() {
        let s = Settings.shared

        columnsField?.integerValue = s.columns
        columnsStepper?.integerValue = s.columns
        rowsField?.integerValue = s.rows
        rowsStepper?.integerValue = s.rows
        gridOpacitySlider?.doubleValue = Double(s.gridOpacity)
        highlightOpacitySlider?.doubleValue = Double(s.highlightOpacity)
        charsetModePopup?.selectItem(at: s.charsetMode.rawValue)
        shortcutField?.setShortcut(keyCode: s.activationKeyCode, modifiers: s.activationModifiers)
        updateSliderLabels()
        updatePermissionStatus()
    }

    @objc private func appDidBecomeActive() {
        updatePermissionStatus()
    }

    private func updatePermissionStatus() {
        let missingPermissions = missingRequiredPermissions()
        if missingPermissions.isEmpty {
            permissionStatusLabel?.stringValue = "Status: ready"
            permissionStatusLabel?.textColor = .systemGreen
        } else {
            permissionStatusLabel?.stringValue = "Status: missing \(missingPermissions.joined(separator: ", "))"
            permissionStatusLabel?.textColor = .systemRed
        }
    }

    private func missingRequiredPermissions() -> [String] {
        var missing: [String] = []

        if !AXIsProcessTrusted() {
            missing.append("Accessibility")
        }

        return missing
    }

    func windowDidBecomeKey(_ notification: Notification) {
        updatePermissionStatus()
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func runShortcutSelfTest() -> [String] {
        var results: [String] = []

        guard let window else {
            return ["FAIL: settings window is missing"]
        }
        guard let contentView = window.contentView else {
            return ["FAIL: settings content view is missing"]
        }
        guard let shortcutField else {
            return ["FAIL: shortcut field is missing"]
        }

        contentView.layoutSubtreeIfNeeded()
        results.append(window.isVisible ? "PASS: settings window is visible" : "FAIL: settings window is not visible")
        results.append(NSApp.isActive ? "PASS: app is active" : "FAIL: app is not active")
        results.append(window.isKeyWindow ? "PASS: settings window is key" : "FAIL: settings window is not key")
        results.append("INFO: shortcut frame = \(NSStringFromRect(shortcutField.frame))")
        results.append("INFO: shortcut superview is contentView = \(shortcutField.superview === contentView)")
        results.append("INFO: shortcut superview type = \(shortcutField.superview.map { String(describing: type(of: $0)) } ?? "nil")")
        results.append("INFO: shortcut superview frame = \(shortcutField.superview.map { NSStringFromRect($0.frame) } ?? "nil")")
        results.append("INFO: contentView subview count = \(contentView.subviews.count)")

        let hitPoint = shortcutField.convert(
            NSPoint(x: shortcutField.bounds.midX, y: shortcutField.bounds.midY),
            to: contentView
        )
        let hitView = contentView.hitTest(hitPoint)
        let hitViewType = hitView.map { String(describing: type(of: $0)) } ?? "nil"
        results.append("INFO: hit view = \(hitViewType)")
        let localHitPoint = shortcutField.convert(hitPoint, from: contentView)
        results.append("INFO: shortcut local hit point = \(NSStringFromPoint(localHitPoint))")
        let directHitView = shortcutField.hitTest(localHitPoint)
        let directHitType = directHitView.map { String(describing: type(of: $0)) } ?? "nil"
        results.append("INFO: direct shortcut hit view = \(directHitType)")
        if let superview = shortcutField.superview {
            let superviewHitPoint = superview.convert(hitPoint, from: contentView)
            results.append("INFO: shortcut superview local hit point = \(NSStringFromPoint(superviewHitPoint))")
            let superviewHitView = superview.hitTest(superviewHitPoint)
            let superviewHitType = superviewHitView.map { String(describing: type(of: $0)) } ?? "nil"
            results.append("INFO: shortcut superview hit view = \(superviewHitType)")
        }
        results.append(hitView === shortcutField ? "PASS: shortcut field receives hit testing" : "FAIL: shortcut field hit testing misses target")

        let windowHitPoint = shortcutField.convert(
            NSPoint(x: shortcutField.bounds.midX, y: shortcutField.bounds.midY),
            to: nil
        )
        results.append("INFO: window hit point = \(NSStringFromPoint(windowHitPoint))")

        let clickEvent = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: windowHitPoint,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 1
        )
        let mouseUpEvent = NSEvent.mouseEvent(
            with: .leftMouseUp,
            location: windowHitPoint,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 0
        )
        if let clickEvent {
            window.sendEvent(clickEvent)
        }
        if let mouseUpEvent {
            window.sendEvent(mouseUpEvent)
        }

        results.append(shortcutField.isRecordingShortcut ? "PASS: window event enters shortcut recording mode" : "FAIL: window event did not enter shortcut recording mode")
        if !shortcutField.isRecordingShortcut {
            shortcutField.performClick(nil)
        }

        results.append(shortcutField.isRecordingShortcut ? "PASS: shortcut field enters recording mode" : "FAIL: shortcut field did not enter recording mode")
        results.append(ShortcutRecordingState.isRecording ? "PASS: global recording state is set" : "FAIL: global recording state was not set")

        let keyEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.option],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            characters: "g",
            charactersIgnoringModifiers: "g",
            isARepeat: false,
            keyCode: 5
        )
        if let keyEvent {
            shortcutField.keyDown(with: keyEvent)
        }

        results.append(!shortcutField.isRecordingShortcut ? "PASS: shortcut field exits recording mode after key press" : "FAIL: shortcut field stayed in recording mode")
        results.append(shortcutField.keyCode == 5 ? "PASS: shortcut field captured key code" : "FAIL: shortcut field did not capture key code")
        results.append(shortcutField.modifiers.contains(.maskAlternate) ? "PASS: shortcut field captured modifiers" : "FAIL: shortcut field did not capture modifiers")

        applyTapped()

        let persistedKeyCode = Settings.shared.activationKeyCode
        let persistedModifiers = Settings.shared.activationModifiers
        results.append(persistedKeyCode == 5 ? "PASS: shortcut key code persisted" : "FAIL: shortcut key code did not persist")
        results.append(persistedModifiers.contains(.maskAlternate) ? "PASS: shortcut modifiers persisted" : "FAIL: shortcut modifiers did not persist")

        return results
    }
}

extension SettingsWindowController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField,
              let stepper = stepperWithTag(field.tag)
        else { return }
        stepper.integerValue = field.integerValue
    }

    private func stepperWithTag(_ tag: Int) -> NSStepper? {
        switch tag {
        case 0:
            return columnsStepper
        case 1:
            return rowsStepper
        default:
            return nil
        }
    }
}
