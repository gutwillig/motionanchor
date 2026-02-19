import Foundation
import AppKit

/// App-wide constants for the Mac app
enum Constants {

    /// App information
    enum App {
        static let name = "MotionAnchor"
        static let version = "1.0.0"
        static let build = "1"
        static let bundleIdentifier = "com.motionanchor.mac"
    }

    /// Default values for dot appearance
    enum Defaults {
        static let dotCount = 10
        static let dotSize: CGFloat = 12
        static let dotOpacity: CGFloat = 0.5
        static let dotInset: CGFloat = 60  // Distance from screen edge

        static let maxDotCount = 20
        static let minDotCount = 4
        static let maxDotSize: CGFloat = 24
        static let minDotSize: CGFloat = 6
    }

    /// Default values for motion processing
    enum Motion {
        static let sensitivityMultiplier = 1.0
        static let smoothingAlpha = 0.3
        static let maxDisplacement: CGFloat = 150

        static let lateralGain = 300.0    // px per g-force
        static let longitudinalGain = 200.0
        static let verticalGain = 100.0
        static let yawGain = 50.0         // px per rad/s
    }

    /// Animation timings
    enum Animation {
        static let returnHomeDuration: TimeInterval = 1.0
        static let connectionRetryDelay: TimeInterval = 2.0
        static let idleDetectionTime: TimeInterval = 10.0
    }

    /// Window levels
    enum WindowLevel {
        static let overlay: Int = Int(CGWindowLevelForKey(.screenSaverWindow))
    }
}
