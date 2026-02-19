import AppKit

// Pure AppKit entry point - no SwiftUI App lifecycle
// This avoids layout recursion issues with @Published ObservableObjects

private var appDelegate: AppDelegate!

@main
enum AppMain {
    static func main() {
        let app = NSApplication.shared
        appDelegate = AppDelegate()
        app.delegate = appDelegate
        app.run()
    }
}
