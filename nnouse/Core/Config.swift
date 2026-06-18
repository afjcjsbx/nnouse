import CoreGraphics

enum Config {
    static var columns: Int      { Settings.shared.columns }
    static var rows: Int         { Settings.shared.rows }
    static var gridOpacity: CGFloat      { Settings.shared.gridOpacity }
    static var highlightOpacity: CGFloat { Settings.shared.highlightOpacity }
    static var activationKeyCode: Int64       { Settings.shared.activationKeyCode }
    static var activationModifiers: CGEventFlags { Settings.shared.activationModifiers }
    static var mouseFPS: Int     { Settings.shared.mouseFPS }

    // Charset for the main grid labels (depends on the selected mode)
    static var charset: [Character] { Settings.shared.charsetMode.charset }

    // Charset for the precision subgrid (letters + digits + non-shift symbols)
    static let subCharset = Array("qwertyuiopasdfghjklzxcvbnm1234567890-=[];',.")
}
