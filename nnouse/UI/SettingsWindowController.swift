import AppKit
import CoreGraphics

final class SettingsWindowController: NSWindowController {

    static let shared = SettingsWindowController()

    private var shortcutField: ShortcutField?

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
        window.contentView = buildContentView()
    }

    required init?(coder: NSCoder) { fatalError() }

    func showAndFocus() {
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Layout

    private func buildContentView() -> NSView {
        let s = Settings.shared
        let root = NSView()

        let colLabel   = label("Columns")
        let colField   = intField(value: s.columns, tag: 0)
        let colStepper = stepper(value: s.columns, min: 4, max: 40, tag: 0)

        let rowLabel   = label("Lines")
        let rowField   = intField(value: s.rows, tag: 1)
        let rowStepper = stepper(value: s.rows, min: 4, max: 50, tag: 1)

        let opLabel  = label("Grid Opacity")
        let opSlider = NSSlider(value: Double(s.gridOpacity), minValue: 0.05, maxValue: 1.0, target: self, action: #selector(sliderChanged(_:)))
        opSlider.translatesAutoresizingMaskIntoConstraints = false
        opSlider.tag = 2
        let opValue  = valueLabel(String(format: "%.0f%%", s.gridOpacity * 100))
        opValue.tag  = 200

        let hlLabel  = label("Highlight Opacity")
        let hlSlider = NSSlider(value: Double(s.highlightOpacity), minValue: 0.05, maxValue: 1.0, target: self, action: #selector(sliderChanged(_:)))
        hlSlider.translatesAutoresizingMaskIntoConstraints = false
        hlSlider.tag = 5
        let hlValue  = valueLabel(String(format: "%.0f%%", s.highlightOpacity * 100))
        hlValue.tag  = 201

        let fpsLabel   = label("Cursor Movement FPS")
        let fpsField   = intField(value: s.mouseFPS, tag: 3)
        let fpsStepper = stepper(value: s.mouseFPS, min: 30, max: 240, tag: 3)

        let modeLabel = label("Cell Label Order")
        let modePopup = NSPopUpButton()
        modePopup.translatesAutoresizingMaskIntoConstraints = false
        modePopup.tag = 4
        for mode in Settings.CharsetMode.allCases { modePopup.addItem(withTitle: mode.label) }
        modePopup.selectItem(at: s.charsetMode.rawValue)

        let hotkeyLabel = label("Activation Shortcut")
        let sf = ShortcutField(keyCode: s.activationKeyCode, modifiers: s.activationModifiers)
        sf.translatesAutoresizingMaskIntoConstraints = false
        sf.onChange = { [weak self] _, _ in _ = self } // value read in applyTapped
        shortcutField = sf

        let applyBtn = NSButton(title: "Apply", target: self, action: #selector(applyTapped))
        applyBtn.translatesAutoresizingMaskIntoConstraints = false
        applyBtn.bezelStyle = .rounded
        applyBtn.keyEquivalent = "\r"

        // (label, main control, optional accessory)
        let rows: [(NSView, NSView, NSView?)] = [
            (colLabel,    colField,   colStepper),
            (rowLabel,    rowField,   rowStepper),
            (opLabel,     opSlider,   opValue),
            (hlLabel,     hlSlider,   hlValue),
            (fpsLabel,    fpsField,   fpsStepper),
            (modeLabel,   modePopup,  nil),
            (hotkeyLabel, sf,         nil),
        ]

        for (l, c, r) in rows {
            root.addSubview(l); root.addSubview(c)
            if let r { root.addSubview(r) }
        }
        root.addSubview(applyBtn)

        let colW: CGFloat  = 190
        let rowH: CGFloat  = 36
        let startY: CGFloat = 332
        let labelW: CGFloat = 180

        for (i, (l, c, r)) in rows.enumerated() {
            let y = startY - CGFloat(i) * rowH
            l.frame = NSRect(x: 20, y: y, width: labelW, height: 24)
            if r != nil {
                c.frame  = NSRect(x: 210, y: y, width: colW - 28, height: 24)
                r?.frame = NSRect(x: 210 + colW - 26, y: y, width: 26, height: 24)
            } else {
                c.frame = NSRect(x: 210, y: y, width: colW, height: 24)
            }
        }

        applyBtn.frame = NSRect(x: 310, y: 16, width: 90, height: 28)

        [colField, colStepper, rowField, rowStepper, fpsField, fpsStepper].forEach {
            ($0 as? NSTextField)?.delegate = self
            ($0 as? NSStepper)?.target = self
            ($0 as? NSStepper)?.action = #selector(stepperChanged(_:))
        }
        colField.tag = 0; colStepper.tag = 0
        rowField.tag = 1; rowStepper.tag = 1
        fpsField.tag = 3; fpsStepper.tag = 3

        return root
    }

    // MARK: - Factories

    private func label(_ text: String) -> NSTextField {
        let f = NSTextField(labelWithString: text)
        f.alignment = .right
        return f
    }

    private func valueLabel(_ text: String) -> NSTextField {
        let f = NSTextField(labelWithString: text)
        f.textColor = .secondaryLabelColor
        return f
    }

    private func intField(value: Int, tag: Int) -> NSTextField {
        let f = NSTextField()
        f.stringValue = "\(value)"
        f.tag = tag
        f.formatter = intFormatter(min: 1, max: 999)
        return f
    }

    private func stepper(value: Int, min: Int, max: Int, tag: Int) -> NSStepper {
        let s = NSStepper()
        s.integerValue = value
        s.minValue = Double(min)
        s.maxValue = Double(max)
        s.increment = 1
        s.tag = tag
        return s
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
        updateSliderLabels()
    }

    @objc private func sliderChanged(_ sender: NSSlider) {
        updateSliderLabels()
    }

    @objc private func applyTapped() {
        let s = Settings.shared
        if let col = intValue(tag: 0) { s.columns = col }
        if let row = intValue(tag: 1) { s.rows = row }
        if let fps = intValue(tag: 3) { s.mouseFPS = fps }
        if let slider = window?.contentView?.viewWithTag(2) as? NSSlider {
            s.gridOpacity = CGFloat(slider.doubleValue)
        }
        if let slider = window?.contentView?.viewWithTag(5) as? NSSlider {
            s.highlightOpacity = CGFloat(slider.doubleValue)
        }
        if let popup = window?.contentView?.viewWithTag(4) as? NSPopUpButton,
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
        window?.contentView?.subviews.compactMap { $0 as? NSTextField }.first { $0.tag == tag }
    }

    private func intValue(tag: Int) -> Int? {
        fieldWithTag(tag).map { $0.integerValue }
    }

    private func updateSliderLabels() {
        let pairs: [(Int, Int)] = [(2, 200), (5, 201)]
        for (sliderTag, labelTag) in pairs {
            guard
                let slider = window?.contentView?.viewWithTag(sliderTag) as? NSSlider,
                let lbl    = window?.contentView?.viewWithTag(labelTag) as? NSTextField
            else { continue }
            lbl.stringValue = String(format: "%.0f%%", slider.doubleValue * 100)
        }
    }
}

extension SettingsWindowController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField,
              let stepper = window?.contentView?.subviews
                .compactMap({ $0 as? NSStepper })
                .first(where: { $0.tag == field.tag })
        else { return }
        stepper.integerValue = field.integerValue
    }
}
