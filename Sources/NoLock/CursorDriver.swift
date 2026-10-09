import AppKit
@preconcurrency import ApplicationServices
import CoreGraphics
import NoLockCore

@MainActor
final class CursorDriver {
    struct Snapshot: Sendable {
        var location: CGPoint
        var hardwareEvents: UInt64
    }

    // A private source posted at the session tap does not masquerade as hardware input.
    // That lets real mouse/keyboard input reset the idle clock without our nudges doing so.
    private let source = CGEventSource(stateID: .privateState)
    private var returnTimer: Timer?
    private var generation = 0

    static let inputTypes: [CGEventType] = [
        .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
        .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
        .otherMouseDown, .otherMouseUp, .scrollWheel, .keyDown, .keyUp,
        .flagsChanged, .tabletPointer, .tabletProximity,
    ]

    init() {
        source?.localEventsSuppressionInterval = 0
    }

    var accessibilityGranted: Bool { AXIsProcessTrusted() }
    var eventPostingGranted: Bool { CGPreflightPostEventAccess() }

    // Accessibility is the permission shown in System Settings. Quartz's separate
    // posting preflight can lag behind that grant, so either authorization is sufficient.
    var hasPermission: Bool { accessibilityGranted || eventPostingGranted }

    var isButtonHeld: Bool {
        (0..<32).contains { index in
            CGEventSource.buttonState(.combinedSessionState, button: CGMouseButton(rawValue: UInt32(index))!)
        }
    }

    func snapshot() -> Snapshot? {
        guard let location = CGEvent(source: nil)?.location else { return nil }
        let count = Self.inputTypes.reduce(UInt64(0)) { total, type in
            total + UInt64(CGEventSource.counterForEventType(.hidSystemState, eventType: type))
        }
        return Snapshot(location: location, hardwareEvents: count)
    }

    func requestPermission() {
        guard !hasPermission else { return }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        CGRequestPostEventAccess()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Moves two points and returns, unless the user moved or started a drag in the meantime.
    @discardableResult
    func nudge(onMove: @escaping @MainActor (CGPoint) -> Void) -> Bool {
        guard hasPermission, !isButtonHeld, let start = snapshot(), let source,
              let bounds = displayBounds(containing: start.location),
              let target = CursorGeometry.nudge(from: start.location, within: bounds) else { return false }
        cancelReturn()
        let currentGeneration = generation
        postMove(to: target, from: start.location, source: source)
        onMove(target)
        let timer = Timer(timeInterval: 0.18, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let returnSource = self.source, self.generation == currentGeneration,
                      self.hasPermission, !self.isButtonHeld,
                      let current = self.snapshot(),
                      current.hardwareEvents == start.hardwareEvents,
                      CursorGeometry.isNear(current.location, target) else { return }
                self.postMove(to: start.location, from: current.location, source: returnSource)
                onMove(start.location)
                self.returnTimer = nil
            }
        }
        returnTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        return true
    }

    func cancelReturn() {
        generation += 1
        returnTimer?.invalidate()
        returnTimer = nil
    }

    private func postMove(to point: CGPoint, from previous: CGPoint, source: CGEventSource) {
        guard let event = CGEvent(mouseEventSource: source, mouseType: .mouseMoved,
                                  mouseCursorPosition: point, mouseButton: .left) else { return }
        event.flags = CGEventSource.flagsState(.combinedSessionState)
        event.setIntegerValueField(.mouseEventDeltaX, value: Int64(point.x - previous.x))
        event.setIntegerValueField(.mouseEventDeltaY, value: Int64(point.y - previous.y))
        event.post(tap: .cgSessionEventTap)
    }

    private func displayBounds(containing point: CGPoint) -> CGRect? {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return nil }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &displays, &count) == .success else { return nil }
        return displays.prefix(Int(count)).map(CGDisplayBounds).first { $0.contains(point) }
    }
}
