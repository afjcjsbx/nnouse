import CoreGraphics
import AppKit

// MARK: - Main grid labels

// Generates the label sequence ordered by priority on the current charset:
//   1. letter × letter  (aa, ab … zz)
//   2. letter × digit   (a0 … z9)
//   3. digit  × letter  (0a … 9z)
//   4. digit  × digit   (00 … 99)
//   5. letter × symbol, digit × symbol, symbol × any
func buildLabelSequence(charset: [Character]) -> [String] {
    let letters = charset.filter { $0.isLetter }
    let digits  = charset.filter { $0.isNumber }
    let symbols = charset.filter { !$0.isLetter && !$0.isNumber }
    var result: [String] = []
    for a in letters { for b in letters { result.append("\(a)\(b)") } }
    for a in letters { for b in digits  { result.append("\(a)\(b)") } }
    for a in digits  { for b in letters { result.append("\(a)\(b)") } }
    for a in digits  { for b in digits  { result.append("\(a)\(b)") } }
    for a in letters { for b in symbols { result.append("\(a)\(b)") } }
    for a in digits  { for b in symbols { result.append("\(a)\(b)") } }
    for a in symbols { for b in charset { result.append("\(a)\(b)") } }
    return result
}

// Cache invalidated when the charset mode changes
private var _cachedCharsetMode: Settings.CharsetMode? = nil
private var _labelSequence: [String] = []
private var _labelIndex: [String: Int] = [:]

private func ensureCache() {
    let mode = Settings.shared.charsetMode
    guard mode != _cachedCharsetMode else { return }
    _labelSequence = buildLabelSequence(charset: mode.charset)
    _labelIndex = Dictionary(uniqueKeysWithValues: _labelSequence.enumerated().map { ($1, $0) })
    _cachedCharsetMode = mode
}

func gridLabel(for index: Int) -> String {
    ensureCache()
    precondition(index < _labelSequence.count, "Index \(index) out of range (max \(_labelSequence.count - 1))")
    return _labelSequence[index]
}

func gridIndex(for label: String, cols: Int, rows: Int) -> Int? {
    ensureCache()
    guard let idx = _labelIndex[label], idx < cols * rows else { return nil }
    return idx
}

// MARK: - Sub-grid layout

// Returns (cols, rows) that best approximate the cell's aspect ratio
func subGridDimensions(cellW: CGFloat, cellH: CGFloat) -> (cols: Int, rows: Int) {
    let n = Config.subCharset.count
    let aspect = cellW / max(cellH, 1)
    var bestCols = n
    var bestRows = 1
    for c in 1...n {
        let r = Int(ceil(Double(n) / Double(c)))
        let a = CGFloat(c) / CGFloat(r)
        if abs(a - aspect) < abs(CGFloat(bestCols) / CGFloat(bestRows) - aspect) {
            bestCols = c
            bestRows = r
        }
    }
    return (bestCols, bestRows)
}

// Normalized offset (0…1, 0…1) of the character within the sub-grid
func subOffset(for ch: Character, subCols: Int) -> CGPoint? {
    guard let idx = Config.subCharset.firstIndex(of: ch) else { return nil }
    let i = Config.subCharset.distance(from: Config.subCharset.startIndex, to: idx)
    let subRows = Int(ceil(Double(Config.subCharset.count) / Double(subCols)))
    let col = i % subCols
    let row = i / subCols
    return CGPoint(
        x: (CGFloat(col) + 0.5) / CGFloat(subCols),
        y: (CGFloat(row) + 0.5) / CGFloat(subRows)
    )
}

// MARK: - Coordinate conversion

// CG coordinates (origin at top-left of primary screen) from the center of a cell
func cgPoint(forCellIndex index: Int, cols: Int, rows: Int, windowFrame: NSRect) -> CGPoint {
    let cellW = windowFrame.width / CGFloat(cols)
    let cellH = windowFrame.height / CGFloat(rows)
    let col = index % cols
    let row = index / cols
    let primaryH = NSScreen.screens[0].frame.height
    let nsX = windowFrame.origin.x + CGFloat(col) * cellW + cellW / 2
    let nsY = windowFrame.origin.y + windowFrame.height - CGFloat(row) * cellH - cellH / 2
    return CGPoint(x: nsX, y: primaryH - nsY)
}

// CG coordinates refined via normalized sub-grid offset
func cgPoint(forCellIndex index: Int, subOffset offset: CGPoint, cols: Int, rows: Int, windowFrame: NSRect) -> CGPoint {
    let cellW = windowFrame.width / CGFloat(cols)
    let cellH = windowFrame.height / CGFloat(rows)
    let col = index % cols
    let row = index / cols
    let primaryH = NSScreen.screens[0].frame.height
    let cellOriginX = windowFrame.origin.x + CGFloat(col) * cellW
    let cellOriginY = windowFrame.origin.y + windowFrame.height - CGFloat(row + 1) * cellH
    let nsX = cellOriginX + offset.x * cellW
    let nsY = cellOriginY + (1 - offset.y) * cellH
    return CGPoint(x: nsX, y: primaryH - nsY)
}
