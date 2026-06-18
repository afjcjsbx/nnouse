import AppKit

final class OverlayWindow: NSWindow {

    private var gridView: GridView!
    private var inputBuffer = ""
    private var state: State = .idle
    private let cols: Int
    private let rows: Int
    private let screenFrame: NSRect

    private enum State {
        case idle
        case cellSelected(Int)
    }

    init(screen: NSScreen, cols: Int, rows: Int) {
        self.cols = cols
        self.rows = rows
        self.screenFrame = screen.frame
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        ignoresMouseEvents = true
        setFrame(screen.frame, display: false)

        gridView = GridView(frame: NSRect(origin: .zero, size: screen.frame.size), cols: cols, rows: rows)
        contentView = gridView
    }

    @discardableResult
    func handleKey(_ key: String) -> Bool {
        let ch = key.lowercased()
        guard ch.count == 1, let scalar = ch.unicodeScalars.first else { return false }
        let v = scalar.value

        if v == 27 { // Esc
            dismiss()
            return true
        }

        switch state {
        case .idle:
            if v == 32 { return true }
            guard Config.charset.contains(Character(ch)) else { return false }
            inputBuffer.append(ch)
            if inputBuffer.count == 1 {
                gridView.firstChar = Character(ch)
            } else if inputBuffer.count == 2 {
                let target = inputBuffer
                inputBuffer = ""
                gridView.firstChar = nil
                if let idx = gridIndex(for: target, cols: cols, rows: rows) {
                    state = .cellSelected(idx)
                    gridView.selectedIndex = idx
                    gridView.subCellChar = nil
                }
            }

        case .cellSelected(let idx):
            if v == 32 { // Space → click at center
                let point = cgPoint(forCellIndex: idx, cols: cols, rows: rows, windowFrame: screenFrame)
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { performClick(at: point) }
                return true
            }

            let qCh = Character(ch)
            let cellW = screenFrame.width / CGFloat(cols)
            let cellH = screenFrame.height / CGFloat(rows)
            let (subCols, _) = subGridDimensions(cellW: cellW, cellH: cellH)
            if let offset = subOffset(for: qCh, subCols: subCols) {
                let point = cgPoint(forCellIndex: idx, subOffset: offset, cols: cols, rows: rows, windowFrame: screenFrame)
                gridView.subCellChar = qCh
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { performClick(at: point) }
                return true
            }
        }

        return true
    }

    // Resets state without destroying the window (used before showing it again)
    func reset() {
        inputBuffer = ""
        state = .idle
        gridView.selectedIndex = nil
        gridView.firstChar = nil
        gridView.subCellChar = nil
        gridView.needsDisplay = true
    }

    func dismiss() {
        reset()
        orderOut(nil)
    }
}
