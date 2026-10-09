import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: AwakeController!
    private var statusItem: NSStatusItem!
    private var controlsWindow: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Opening the bundle again should reveal the existing instance.
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "local.nolock.app")
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        if !others.isEmpty {
            DistributedNotificationCenter.default().postNotificationName(.init("local.nolock.show"), object: nil)
            NSApplication.shared.terminate(nil)
            return
        }

        controller = AwakeController()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(toggleWindow)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        let hosting = NSHostingController(rootView: ControlsView(controller: controller))
        controlsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 370, height: 550),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        controlsWindow.title = "NoLock"
        controlsWindow.titlebarAppearsTransparent = true
        controlsWindow.isMovableByWindowBackground = true
        controlsWindow.isReleasedWhenClosed = false
        controlsWindow.level = .floating
        controlsWindow.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        controlsWindow.appearance = NSAppearance(named: .darkAqua)
        controlsWindow.backgroundColor = NSColor(red: 0.075, green: 0.085, blue: 0.105, alpha: 1)
        controlsWindow.contentViewController = hosting
        controlsWindow.setContentSize(hosting.view.fittingSize)
        if !controlsWindow.setFrameUsingName("NoLockControls") {
            controlsWindow.center()
        }
        controlsWindow.setFrameAutosaveName("NoLockControls")
        controller.onStatusChange = { [weak self] in
            self?.updateStatusIcon()
            // SwiftUI applies the permission-card change on the next main-loop turn.
            DispatchQueue.main.async { [weak self] in self?.resizeControlsWindowToFit() }
        }
        updateStatusIcon()
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(showWindow),
                                                           name: .init("local.nolock.show"), object: nil)
        // Show setup on first run, but stay unobtrusive on subsequent login launches.
        if !UserDefaults.standard.bool(forKey: "hasLaunched") || CommandLine.arguments.contains("--show") {
            UserDefaults.standard.set(true, forKey: "hasLaunched")
            showWindow()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.shutdown()
        DistributedNotificationCenter.default().removeObserver(self)
    }

    @objc private func toggleWindow() {
        if NSApplication.shared.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else if controlsWindow.isVisible {
            controlsWindow.orderOut(nil)
        } else {
            showWindow()
        }
    }

    @objc private func showWindow() {
        guard let window = controlsWindow else { return }
        controller.refreshPermissions()
        // Keep the entire window visible if the display arrangement changed since the last run.
        if let screen = window.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            var frame = window.frame
            frame.origin.x = max(visible.minX, min(frame.minX, visible.maxX - frame.width))
            frame.origin.y = max(visible.minY, min(frame.minY, visible.maxY - frame.height))
            window.setFrame(frame, display: false)
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func resizeControlsWindowToFit() {
        guard let window = controlsWindow, let view = window.contentViewController?.view else { return }
        view.layoutSubtreeIfNeeded()
        let fitting = view.fittingSize
        guard fitting.width > 0, fitting.height > 0 else { return }
        let top = window.frame.maxY
        window.setContentSize(fitting)
        var frame = window.frame
        frame.origin.y = top - frame.height
        if let screen = window.screen ?? NSScreen.main {
            frame.origin.y = max(screen.visibleFrame.minY,
                                 min(frame.minY, screen.visibleFrame.maxY - frame.height))
        }
        window.setFrame(frame, display: true)
    }

    private func updateStatusIcon() {
        let symbol = controller.keepingAwake ? "cursorarrow.motionlines" : "cursorarrow"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "NoLock: \(controller.title)")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = "NoLock — \(controller.title)"
    }

    private func showMenu() {
        let menu = NSMenu()
        let toggle = NSMenuItem(title: controller.enabled ? "Pause NoLock" : "Keep Mac awake",
                                action: #selector(toggleEnabled), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)
        let open = NSMenuItem(title: "Open NoLock…", action: #selector(showWindow), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit NoLock", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func toggleEnabled() { controller.setEnabled(!controller.enabled) }
}

@main
enum NoLockApp {
    @MainActor
    static func main() {
        if CommandLine.arguments.contains("--smoke-test") {
            let power = PowerAssertions()
            let started = power.start()
            let activity = started && power.declareActivity()
            print("Power assertions: \(started ? "PASS" : "FAIL")")
            print("User activity pulse: \(activity ? "PASS" : "FAIL")")
            let cursor = CursorDriver()
            print("Accessibility permission: \(cursor.accessibilityGranted ? "granted" : "not granted")")
            print("Event posting permission: \(cursor.eventPostingGranted ? "granted" : "not granted")")
            print("Cursor permission: \(cursor.hasPermission ? "granted" : "requires Accessibility")")
            if let snapshot = cursor.snapshot() {
                print("Cursor position: \(snapshot.location.x), \(snapshot.location.y)")
                print("Hardware event counter: \(snapshot.hardwareEvents)")
            }
            power.stop()
            print("Power assertions released: \(!power.isActive ? "PASS" : "FAIL")")
            if !started || !activity { exit(1) }
            return
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
        withExtendedLifetime(delegate) {}
    }
}
