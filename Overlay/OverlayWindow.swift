import AppKit
import Foundation
import Combine
import CoreVideo

/// Transparent, click-through overlay window that displays motion dots
final class OverlayWindow: NSPanel {

    /// Creates an overlay window covering the specified screen
    init(for screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        configureWindow()
    }

    private func configureWindow() {
        // Transparent background
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false

        // Always on top (above most windows, including fullscreen)
        level = .screenSaver

        // Click-through - never intercept mouse events
        ignoresMouseEvents = true

        // Appear on all Spaces/Desktops
        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary
        ]

        // No title bar, no buttons
        titleVisibility = .hidden
        titlebarAppearsTransparent = true

        // Exclude from screen recordings/screenshots
        sharingType = .none

        // Don't show in Dock or Mission Control
        isExcludedFromWindowsMenu = true

        // Allow it to be above fullscreen windows if possible
        // Note: This may not work for all fullscreen apps due to macOS restrictions

        // Make it visible
        orderFrontRegardless()
    }

    /// Update the window to cover a new screen frame
    func updateFrame(to frame: NSRect) {
        setFrame(frame, display: true)
    }
}

/// Manages overlay windows across all connected displays
final class OverlayWindowManager: ObservableObject {

    @Published var isOverlayVisible = false

    private var overlayWindows: [NSScreen: OverlayWindow] = [:]
    private var dotViews: [NSScreen: DotOverlayView] = [:]

    // Dot rendering
    private var dotRenderer: DotRenderer?
    private var displayTimer: Timer?

    // Screen change observer
    private var screenObserver: NSObjectProtocol?

    init() {
        setupScreenObserver()
    }

    deinit {
        hideOverlay()
        if let observer = screenObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public Methods

    /// Show overlay windows on all screens
    func showOverlay() {
        print("DEBUG: showOverlay called, isVisible: \(isOverlayVisible)")
        guard !isOverlayVisible else { return }

        for screen in NSScreen.screens {
            createOverlayWindow(for: screen)
        }

        startDisplayLink()
        isOverlayVisible = true
    }

    /// Hide all overlay windows
    func hideOverlay() {
        print("DEBUG: hideOverlay called, isVisible: \(isOverlayVisible)")
        stopDisplayLink()

        for (_, window) in overlayWindows {
            window.close()
        }
        overlayWindows.removeAll()
        dotViews.removeAll()

        isOverlayVisible = false
    }

    /// Toggle overlay visibility
    func toggleOverlay() {
        print("DEBUG: toggleOverlay called, isVisible: \(isOverlayVisible)")
        if isOverlayVisible {
            hideOverlay()
        } else {
            showOverlay()
        }
    }

    /// Set the dot renderer for motion-based updates
    func setDotRenderer(_ renderer: DotRenderer) {
        self.dotRenderer = renderer

        // Update all dot views with the renderer
        for (_, dotView) in dotViews {
            dotView.dotRenderer = renderer
        }
    }

    /// Force redraw of all dots
    func setNeedsDisplay() {
        for (_, dotView) in dotViews {
            dotView.needsDisplay = true
        }
    }

    // MARK: - Private Methods

    private func createOverlayWindow(for screen: NSScreen) {
        let window = OverlayWindow(for: screen)

        // Create dot view
        let dotView = DotOverlayView(frame: screen.frame)
        dotView.dotRenderer = dotRenderer
        window.contentView = dotView

        overlayWindows[screen] = window
        dotViews[screen] = dotView
    }

    private func setupScreenObserver() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenChange()
        }
    }

    private func handleScreenChange() {
        guard isOverlayVisible else { return }

        // Close all windows and recreate for new screen configuration
        hideOverlay()
        showOverlay()
    }

    // MARK: - Display Timer

    private func startDisplayLink() {
        guard displayTimer == nil else { return }

        // 30fps for smooth dot movement
        displayTimer = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { [weak self] _ in
            self?.setNeedsDisplay()
        }
        print("DEBUG: Display timer started at 30fps")
    }

    private func stopDisplayLink() {
        displayTimer?.invalidate()
        displayTimer = nil
        print("DEBUG: Display timer stopped")
    }
}
