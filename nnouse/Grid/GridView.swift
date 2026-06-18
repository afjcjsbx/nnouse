import AppKit

final class GridView: NSView {

    var selectedIndex: Int? { didSet { needsDisplay = true } }
    var firstChar: Character? { didSet { needsDisplay = true } }
    var subCellChar: Character? { didSet { needsDisplay = true } }

    private let cols: Int
    private let rows: Int

    init(frame: NSRect, cols: Int, rows: Int) {
        self.cols = cols
        self.rows = rows
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let cellW = bounds.width / CGFloat(cols)
        let cellH = bounds.height / CGFloat(rows)

        NSColor(white: 0, alpha: Config.gridOpacity).setFill()
        bounds.fill()

        let total = cols * rows
        for i in 0..<total {
            let col = i % cols
            let row = i / cols
            let rect = NSRect(
                x: CGFloat(col) * cellW,
                y: bounds.height - CGFloat(row + 1) * cellH,
                width: cellW,
                height: cellH
            )

            let lbl = gridLabel(for: i)
            let matchesFirst = firstChar.map { lbl.first == $0 } ?? false

            if i == selectedIndex {
                NSColor(red: 1.0, green: 0.92, blue: 0.2, alpha: 0.35).setFill()
                rect.fill()
                drawSubGrid(in: rect)
            } else if matchesFirst {
                NSColor(red: 1.0, green: 0.88, blue: 0.0, alpha: Config.highlightOpacity).setFill()
                rect.fill()
            }

            let path = NSBezierPath(rect: rect)
            NSColor(white: 1, alpha: matchesFirst ? 0.7 : 0.15).setStroke()
            path.lineWidth = matchesFirst ? 1.0 : 0.5
            path.stroke()

            guard i != selectedIndex else { continue }

            let textAlpha: CGFloat = matchesFirst ? 1.0 : 0.85
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: min(cellW, cellH) * 0.28, weight: matchesFirst ? .bold : .semibold),
                .foregroundColor: matchesFirst
                    ? NSColor(red: 1.0, green: 0.95, blue: 0.3, alpha: 1.0)
                    : NSColor(white: 1, alpha: textAlpha)
            ]
            let str = NSAttributedString(string: lbl.uppercased(), attributes: attrs)
            let sz = str.size()
            str.draw(at: NSPoint(x: rect.midX - sz.width / 2, y: rect.midY - sz.height / 2))
        }
    }

    private func drawSubGrid(in cellRect: NSRect) {
        let (subCols, _) = subGridDimensions(cellW: cellRect.width, cellH: cellRect.height)
        let subRows = Int(ceil(Double(Config.subCharset.count) / Double(subCols)))
        let subCellW = cellRect.width / CGFloat(subCols)
        let subCellH = cellRect.height / CGFloat(subRows)

        for (i, ch) in Config.subCharset.enumerated() {
            let col = i % subCols
            let row = i / subCols
            let subRect = NSRect(
                x: cellRect.minX + CGFloat(col) * subCellW,
                y: cellRect.maxY - CGFloat(row + 1) * subCellH,
                width: subCellW,
                height: subCellH
            )

            if subCellChar == ch {
                NSColor(red: 1.0, green: 0.95, blue: 0.3, alpha: 0.7).setFill()
                subRect.fill()
            }

            let border = NSBezierPath(rect: subRect)
            NSColor(red: 1.0, green: 0.9, blue: 0.2, alpha: 0.3).setStroke()
            border.lineWidth = 0.5
            border.stroke()

            let fontSize = min(subCellW, subCellH) * 0.42
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold),
                .foregroundColor: subCellChar == ch
                    ? NSColor.black
                    : NSColor(red: 1.0, green: 0.95, blue: 0.5, alpha: 0.95)
            ]
            let str = NSAttributedString(string: String(ch).uppercased(), attributes: attrs)
            let sz = str.size()
            str.draw(at: NSPoint(x: subRect.midX - sz.width / 2, y: subRect.midY - sz.height / 2))
        }
    }
}
