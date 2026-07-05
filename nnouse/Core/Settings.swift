import CoreGraphics
import Foundation

final class Settings {

    static let shared = Settings()

    private let defaults = UserDefaults.standard

    enum CharsetMode: Int, CaseIterable {
        case alphabetical = 0   // aa, ab, ac... alphabetical order
        case homeRowFirst = 1   // Home row first: asdfghjkl have priority
        case spatialMapping = 2 // keyboard lines → screen lines
        case alternatingHands = 3 // alternation between left and right

        var label: String {
            switch self {
            case .alphabetical:    return "Alphabetical (AA, AB…)"
            case .homeRowFirst:    return "Home Row First"
            case .spatialMapping:  return "Spatial Mapping"
            case .alternatingHands: return "Alternating Hands"
            }
        }

        var charset: [Character] {
            switch self {
            case .alphabetical:
                return Array("abcdefghijklmnopqrstuvwxyz0123456789-=/,.")
            case .homeRowFirst:
                return Array("asdfjklghqwertyuiopzxcvbnm1234567890-=/,.")
            case .spatialMapping:
                return Array("qwertyuiopasdfghjklzxcvbnm1234567890-=/,.")
            case .alternatingHands:
                return Array("afsdjkghqpwoerituybnmvczxl1234567890-=/,.")
            }
        }
    }

    private enum Key: String {
        case columns, rows, gridOpacity, highlightOpacity, activationKeyCode, activationModifiers, charsetMode
    }

    var columns: Int {
        get { let v = defaults.integer(forKey: Key.columns.rawValue); return v > 0 ? v : 16 }
        set { defaults.set(newValue, forKey: Key.columns.rawValue); notify() }
    }

    var rows: Int {
        get { let v = defaults.integer(forKey: Key.rows.rawValue); return v > 0 ? v : 22 }
        set { defaults.set(newValue, forKey: Key.rows.rawValue); notify() }
    }

    var gridOpacity: CGFloat {
        get {
            let v = defaults.double(forKey: Key.gridOpacity.rawValue)
            return v > 0 ? CGFloat(v) : 0.20
        }
        set { defaults.set(Double(newValue), forKey: Key.gridOpacity.rawValue); notify() }
    }

    var highlightOpacity: CGFloat {
        get {
            let v = defaults.double(forKey: Key.highlightOpacity.rawValue)
            return v > 0 ? CGFloat(v) : 0.45
        }
        set { defaults.set(Double(newValue), forKey: Key.highlightOpacity.rawValue); notify() }
    }

    // keyCode of the activation key (default 49 = space)
    var activationKeyCode: Int64 {
        get {
            guard defaults.object(forKey: Key.activationKeyCode.rawValue) != nil else { return 49 }
            return Int64(defaults.integer(forKey: Key.activationKeyCode.rawValue))
        }
        set { defaults.set(Int(newValue), forKey: Key.activationKeyCode.rawValue); notify() }
    }

    // Activation modifiers such as raw CGEventFlags (default: maskAlternate = ⌥)
    var activationModifiers: CGEventFlags {
        get {
            let v = defaults.object(forKey: Key.activationModifiers.rawValue) as? UInt64
            return v.map { CGEventFlags(rawValue: $0) } ?? .maskAlternate
        }
        set { defaults.set(newValue.rawValue, forKey: Key.activationModifiers.rawValue); notify() }
    }

    var charsetMode: CharsetMode {
        get { CharsetMode(rawValue: defaults.integer(forKey: Key.charsetMode.rawValue)) ?? .alphabetical }
        set { defaults.set(newValue.rawValue, forKey: Key.charsetMode.rawValue); notify() }
    }

    static let didChangeNotification = Notification.Name("nnouse.settingsDidChange")

    private func notify() {
        NotificationCenter.default.post(name: Settings.didChangeNotification, object: self)
    }
}
