import AppKit
import Combine
import NoLockCore
import ServiceManagement

@MainActor
final class AwakeController: ObservableObject {
    @Published private(set) var enabled: Bool
    @Published private(set) var hasPermission = false
    @Published private(set) var keepingAwake = false
    @Published private(set) var sessionActive = true
    @Published private(set) var idleSeconds: TimeInterval = 0
    @Published private(set) var nudgeCount = 0
    @Published private(set) var lastNudge: Date?
    @Published private(set) var error: String?
    @Published private(set) var loginEnabled = false
    @Published private(set) var loginNeedsApproval = false

    let power = PowerAssertions()
    let cursor = CursorDriver()
    private var policy = IdlePolicy(now: ProcessInfo.processInfo.systemUptime)
    private var previousSnapshot: CursorDriver.Snapshot?
    private var timer: Timer?
    private var lastActivityPulse: TimeInterval = -.infinity
    private var lastPowerAttempt: TimeInterval = -.infinity
    private var observers: [NSObjectProtocol] = []
    private var appObservers: [NSObjectProtocol] = []
    private var pulseOK = true
    var onStatusChange: (() -> Void)?

    init() {
        enabled = UserDefaults.standard.object(forKey: "enabled") as? Bool ?? true
        hasPermission = cursor.hasPermission
        previousSnapshot = cursor.snapshot()
        refreshLoginStatus()
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.sessionDidResignActiveNotification, NSWorkspace.willSleepNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.setSessionActive(false) }
            })
        }
        for name in [NSWorkspace.sessionDidBecomeActiveNotification, NSWorkspace.didWakeNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.setSessionActive(true) }
            })
        }
        appObservers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshPermissions() }
        })
        applyEnabledState()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = 0.15
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    var title: String {
        if !enabled { return "Paused" }
        if !sessionActive { return "Waiting for your session" }
        if !keepingAwake { return "Needs attention" }
        return hasPermission ? "Your Mac stays awake" : "Display stays awake"
    }

    var detail: String {
        if !enabled { return "Normal sleep and screen saver settings apply." }
        if !sessionActive { return "Protection resumes when you return." }
        if !keepingAwake { return error ?? "Sleep prevention could not start." }
        if !hasPermission { return "Enable Accessibility to add cursor movement." }
        if idleSeconds >= policy.idleThreshold { return "Cursor nudges are keeping idle timers fresh." }
        return "Working in the background. You’re free to step away."
    }

    var idleLabel: String {
        if !enabled { return "Cursor movement paused" }
        if !sessionActive { return "Session inactive" }
        if !hasPermission { return "Cursor movement needs Accessibility" }
        if idleSeconds >= policy.idleThreshold { return "Idle mode · nudging every 30 seconds" }
        let remaining = Int(ceil(policy.idleThreshold - idleSeconds))
        return String(format: "Next idle nudge in %d:%02d", remaining / 60, remaining % 60)
    }

    func setEnabled(_ newValue: Bool) {
        enabled = newValue
        UserDefaults.standard.set(newValue, forKey: "enabled")
        applyEnabledState()
    }

    func refreshPermissions() {
        let permission = cursor.hasPermission
        guard permission != hasPermission else { return }
        hasPermission = permission
        policy.recordActivity(at: ProcessInfo.processInfo.systemUptime)
        idleSeconds = 0
        onStatusChange?()
    }

    func requestPermission() {
        refreshPermissions()
        cursor.requestPermission()
    }

    func testNudge() {
        guard enabled, sessionActive else { return }
        guard cursor.hasPermission else { requestPermission(); return }
        // Give the user time to release the menu click before checking for held buttons.
        let timer = Timer(timeInterval: 0.6, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.enabled, self.sessionActive else { return }
                self.performNudge(at: ProcessInfo.processInfo.systemUptime)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    func setLaunchAtLogin(_ value: Bool) {
        do {
            if value { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            error = nil
        } catch {
            self.error = "Could not change launch at login: \(error.localizedDescription)"
        }
        refreshLoginStatus()
    }

    func openLoginSettings() { SMAppService.openSystemSettingsLoginItems() }

    func shutdown() {
        timer?.invalidate()
        timer = nil
        cursor.cancelReturn()
        power.stop()
        keepingAwake = false
        let center = NSWorkspace.shared.notificationCenter
        observers.forEach { center.removeObserver($0) }
        observers.removeAll()
        appObservers.forEach { NotificationCenter.default.removeObserver($0) }
        appObservers.removeAll()
    }

    private func setSessionActive(_ active: Bool) {
        sessionActive = active
        applyEnabledState()
    }

    private func applyEnabledState() {
        let now = ProcessInfo.processInfo.systemUptime
        policy.recordActivity(at: now)
        idleSeconds = 0
        previousSnapshot = cursor.snapshot()
        cursor.cancelReturn()
        if enabled && sessionActive {
            lastPowerAttempt = now
            keepingAwake = power.start()
            error = power.lastError
            if keepingAwake {
                pulseOK = power.declareActivity()
                lastActivityPulse = now
                if !pulseOK { error = power.lastError }
            }
        } else {
            power.stop()
            keepingAwake = false
        }
        onStatusChange?()
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        refreshPermissions()
        let permission = hasPermission
        refreshLoginStatus()
        if let current = cursor.snapshot() {
            if let previous = previousSnapshot,
               current.hardwareEvents != previous.hardwareEvents || !CursorGeometry.isNear(current.location, previous.location) {
                policy.recordActivity(at: now)
            }
            previousSnapshot = current
        }
        idleSeconds = policy.idleDuration(at: now)
        guard enabled, sessionActive else { return }
        if !keepingAwake && now - lastPowerAttempt >= 30 {
            lastPowerAttempt = now
            keepingAwake = power.start()
            error = power.lastError
            onStatusChange?()
        }
        if keepingAwake && now - lastActivityPulse >= 30 {
            pulseOK = power.declareActivity()
            lastActivityPulse = now
            if !pulseOK { error = power.lastError }
        }
        if policy.shouldNudge(at: now, enabled: enabled, sessionActive: sessionActive,
                              permitted: permission, buttonHeld: cursor.isButtonHeld) {
            performNudge(at: now)
        }
    }

    private func performNudge(at now: TimeInterval) {
        if cursor.nudge(onMove: { [weak self] location in
            // Only replace position; real hardware events must still reset the idle clock.
            self?.previousSnapshot?.location = location
        }) {
            policy.recordNudge(at: now)
            nudgeCount += 1
            lastNudge = Date()
        }
    }

    private func refreshLoginStatus() {
        let status = SMAppService.mainApp.status
        let enabled = status == .enabled || status == .requiresApproval
        if loginEnabled != enabled { loginEnabled = enabled }
        let approval = status == .requiresApproval
        if loginNeedsApproval != approval { loginNeedsApproval = approval }
    }
}
