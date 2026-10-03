import AppKit
import ApplicationServices

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var settingsWindow: SettingsWindowController!
    private var globalClickMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }
        requestPermissions()
        TouchEngine.shared.start()
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { event in
            let kind = event.type == .rightMouseDown ? "物理右键" : "物理左键"
            Task { @MainActor in TouchEngine.shared.recordVisualClick(kind) }
        }
        settingsWindow = SettingsWindowController()
        buildMenu()
        if !TouchEngine.shared.isRunning || CommandLine.arguments.contains("--show-settings") {
            settingsWindow.showWindow(nil)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let globalClickMonitor { NSEvent.removeMonitor(globalClickMonitor) }
        TouchEngine.shared.stop()
    }

    private func requestPermissions() {
        // String value of kAXTrustedCheckOptionPrompt. Using the literal also avoids
        // Swift 6 treating the imported global CFString as unsafe mutable state.
        let promptKey = "AXTrustedCheckOptionPrompt"
        _ = AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
        if !CGPreflightListenEventAccess() { CGRequestListenEventAccess() }
    }

    private func buildMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "magicmouse", accessibilityDescription: "Magic Mouse Flow")
            ?? NSImage(systemSymbolName: "computermouse", accessibilityDescription: "Magic Mouse Flow")
        let menu = NSMenu()
        let state = NSMenuItem(title: TouchEngine.shared.statusText, action: nil, keyEquivalent: "")
        state.isEnabled = false
        menu.addItem(state)
        menu.addItem(.separator())
        menu.addItem(withTitle: "设置…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(withTitle: "暂停/继续", action: #selector(toggleEngine), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }

    @objc private func openSettings() { settingsWindow.showWindow(nil) }
    @objc private func toggleEngine() {
        TouchEngine.shared.isRunning ? TouchEngine.shared.stop() : TouchEngine.shared.start()
        statusItem.menu?.item(at: 0)?.title = TouchEngine.shared.statusText
    }
    @objc private func quit() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
