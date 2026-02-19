import AppKit
import SwiftUI
import MultipeerConnectivity

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private var appState: AppState?
    private var menu: NSMenu?
    private var preferencesWindow: NSWindow?

    // Keep app running even when all windows are closed (menu bar app)
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("DEBUG: MotionAnchor Mac app started!")

        // Initialize app state
        appState = AppState()

        // Set up as menu bar app (no dock icon by default)
        let showDockIcon = UserDefaults.standard.bool(forKey: "showDockIcon")
        NSApp.setActivationPolicy(showDockIcon ? .regular : .accessory)

        // Set up status bar item with menu
        setupStatusItem()

        // Set up global keyboard shortcut
        setupKeyboardShortcut()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Clean up
        appState?.overlayManager.hideOverlay()
        appState?.connectionManager.disconnect()
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "waveform.circle", accessibilityDescription: "MotionAnchor")
        }

        // Create menu with delegate - rebuilds only when opened
        menu = NSMenu()
        menu?.delegate = self
        statusItem?.menu = menu
    }

    private func rebuildMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        // Status
        let statusMenuItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Overlay toggle
        let overlayTitle = (appState?.overlayManager.isOverlayVisible ?? false) ? "Hide Overlay" : "Show Overlay"
        let overlayItem = NSMenuItem(title: overlayTitle, action: #selector(toggleOverlay), keyEquivalent: "M")
        overlayItem.keyEquivalentModifierMask = [.command, .shift]
        overlayItem.target = self
        menu.addItem(overlayItem)

        menu.addItem(NSMenuItem.separator())

        // Connection controls
        if let state = appState?.connectionManager.connectionState {
            switch state {
            case .disconnected:
                let searchItem = NSMenuItem(title: "Search for iPhone", action: #selector(startSearching), keyEquivalent: "")
                searchItem.target = self
                menu.addItem(searchItem)

            case .searching:
                let stopItem = NSMenuItem(title: "Stop Searching", action: #selector(stopSearching), keyEquivalent: "")
                stopItem.target = self
                menu.addItem(stopItem)

                // Show discovered peers
                if let peers = appState?.connectionManager.discoveredPeers, !peers.isEmpty {
                    menu.addItem(NSMenuItem.separator())
                    for peer in peers {
                        let peerItem = NSMenuItem(title: "Connect: \(peer.displayName)", action: #selector(connectToPeer(_:)), keyEquivalent: "")
                        peerItem.target = self
                        peerItem.representedObject = peer
                        menu.addItem(peerItem)
                    }
                }

            case .connecting, .connected, .streaming, .reconnecting:
                let disconnectItem = NSMenuItem(title: "Disconnect", action: #selector(disconnect), keyEquivalent: "")
                disconnectItem.target = self
                menu.addItem(disconnectItem)
            }
        }

        menu.addItem(NSMenuItem.separator())

        // Sensitivity submenu
        let sensitivityMenu = NSMenu()
        for preset in ["Low", "Medium", "High"] {
            let item = NSMenuItem(title: preset, action: #selector(setSensitivity(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = preset
            if preset == appState?.currentSensitivityPreset {
                item.state = .on
            }
            sensitivityMenu.addItem(item)
        }
        let sensitivityItem = NSMenuItem(title: "Sensitivity", action: nil, keyEquivalent: "")
        sensitivityItem.submenu = sensitivityMenu
        menu.addItem(sensitivityItem)

        menu.addItem(NSMenuItem.separator())

        // Preferences
        let prefsItem = NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit MotionAnchor", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
    }

    private var statusText: String {
        guard let state = appState?.connectionManager.connectionState else { return "Not Connected" }
        switch state {
        case .disconnected: return "● Not Connected"
        case .searching: return "● Searching..."
        case .connecting: return "● Connecting..."
        case .connected: return "● Connected"
        case .streaming: return "● Streaming"
        case .reconnecting: return "● Reconnecting..."
        }
    }

    // MARK: - Actions

    @objc private func toggleOverlay() {
        appState?.toggleOverlay()
    }

    @objc private func startSearching() {
        appState?.connectionManager.startBrowsing()
    }

    @objc private func stopSearching() {
        appState?.connectionManager.stopBrowsing()
    }

    @objc private func connectToPeer(_ sender: NSMenuItem) {
        if let peer = sender.representedObject as? MCPeerID {
            appState?.connectionManager.connect(to: peer)
        }
    }

    @objc private func disconnect() {
        appState?.connectionManager.disconnect()
    }

    @objc private func setSensitivity(_ sender: NSMenuItem) {
        if let preset = sender.representedObject as? String {
            switch preset {
            case "Low": appState?.setSensitivityPreset(.low)
            case "Medium": appState?.setSensitivityPreset(.medium)
            case "High": appState?.setSensitivityPreset(.high)
            default: break
            }
        }
    }

    @objc private func openPreferences() {
        guard let appState = appState else { return }

        // Reuse existing window if it exists
        if let window = preferencesWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        preferencesWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        preferencesWindow?.title = "MotionAnchor Preferences"
        preferencesWindow?.contentView = NSHostingView(rootView: PreferencesWindow(appState: appState))
        preferencesWindow?.center()
        preferencesWindow?.makeKeyAndOrderFront(nil)
        preferencesWindow?.isReleasedWhenClosed = false

        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Keyboard Shortcuts

    private func setupKeyboardShortcut() {
        // Register global keyboard shortcut ⌘⇧M to toggle overlay
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // ⌘⇧M
            if event.modifierFlags.contains([.command, .shift]) && event.charactersIgnoringModifiers == "m" {
                self?.appState?.toggleOverlay()
                return nil
            }

            // ⌘, for preferences
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "," {
                self?.openPreferences()
                return nil
            }

            return event
        }
    }
}

// MARK: - NSMenuDelegate

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        // Rebuild menu items only when the menu is about to open
        rebuildMenu(menu)
    }
}
