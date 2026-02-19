import Foundation
import AppKit

// MARK: - UserDefaults Keys

enum SettingsKey: String {
    // Connection
    case lastConnectedPeerName
    case autoConnectEnabled

    // Appearance
    case dotCount
    case dotSize
    case dotOpacity
    case dotShape
    case dotColorRed
    case dotColorGreen
    case dotColorBlue

    // Motion
    case sensitivityMultiplier
    case smoothingAlpha
    case maxDisplacement
    case lateralGain
    case longitudinalGain
    case verticalGain
    case yawGain
    case sensitivityPreset

    // General
    case launchAtLogin
    case showDockIcon
}

// MARK: - Settings Extension

extension UserDefaults {

    // MARK: - Dot Appearance

    var dotCount: Int {
        get { integer(forKey: SettingsKey.dotCount.rawValue).nonZero ?? 10 }
        set { set(newValue, forKey: SettingsKey.dotCount.rawValue) }
    }

    var dotSize: CGFloat {
        get { CGFloat(double(forKey: SettingsKey.dotSize.rawValue).nonZero ?? 12.0) }
        set { set(Double(newValue), forKey: SettingsKey.dotSize.rawValue) }
    }

    var dotOpacity: CGFloat {
        get { CGFloat(double(forKey: SettingsKey.dotOpacity.rawValue).nonZero ?? 0.5) }
        set { set(Double(newValue), forKey: SettingsKey.dotOpacity.rawValue) }
    }

    var dotShape: String {
        get { string(forKey: SettingsKey.dotShape.rawValue) ?? "circle" }
        set { set(newValue, forKey: SettingsKey.dotShape.rawValue) }
    }

    var dotColor: NSColor {
        get {
            let red = CGFloat(double(forKey: SettingsKey.dotColorRed.rawValue))
            let green = CGFloat(double(forKey: SettingsKey.dotColorGreen.rawValue))
            let blue = CGFloat(double(forKey: SettingsKey.dotColorBlue.rawValue))

            if red == 0 && green == 0 && blue == 0 {
                return .black
            }
            return NSColor(red: red, green: green, blue: blue, alpha: 1.0)
        }
        set {
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            newValue.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

            set(Double(red), forKey: SettingsKey.dotColorRed.rawValue)
            set(Double(green), forKey: SettingsKey.dotColorGreen.rawValue)
            set(Double(blue), forKey: SettingsKey.dotColorBlue.rawValue)
        }
    }

    // MARK: - Motion Settings

    var sensitivityMultiplier: Double {
        get { double(forKey: SettingsKey.sensitivityMultiplier.rawValue).nonZero ?? 1.0 }
        set { set(newValue, forKey: SettingsKey.sensitivityMultiplier.rawValue) }
    }

    var smoothingAlpha: Double {
        get { double(forKey: SettingsKey.smoothingAlpha.rawValue).nonZero ?? 0.3 }
        set { set(newValue, forKey: SettingsKey.smoothingAlpha.rawValue) }
    }

    var maxDisplacement: CGFloat {
        get { CGFloat(double(forKey: SettingsKey.maxDisplacement.rawValue).nonZero ?? 150.0) }
        set { set(Double(newValue), forKey: SettingsKey.maxDisplacement.rawValue) }
    }

    var lateralGain: Double {
        get { double(forKey: SettingsKey.lateralGain.rawValue).nonZero ?? 300.0 }
        set { set(newValue, forKey: SettingsKey.lateralGain.rawValue) }
    }

    var longitudinalGain: Double {
        get { double(forKey: SettingsKey.longitudinalGain.rawValue).nonZero ?? 200.0 }
        set { set(newValue, forKey: SettingsKey.longitudinalGain.rawValue) }
    }

    var verticalGain: Double {
        get { double(forKey: SettingsKey.verticalGain.rawValue).nonZero ?? 100.0 }
        set { set(newValue, forKey: SettingsKey.verticalGain.rawValue) }
    }

    var yawGain: Double {
        get { double(forKey: SettingsKey.yawGain.rawValue).nonZero ?? 50.0 }
        set { set(newValue, forKey: SettingsKey.yawGain.rawValue) }
    }
}

// MARK: - Helpers

extension Int {
    var nonZero: Int? {
        self != 0 ? self : nil
    }
}

extension Double {
    var nonZero: Double? {
        self != 0 ? self : nil
    }
}
