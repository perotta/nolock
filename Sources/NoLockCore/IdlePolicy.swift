import Foundation
import CoreGraphics

/// Uses monotonic time so changing the clock cannot trigger a cursor move.
public struct IdlePolicy: Sendable {
    public let idleThreshold: TimeInterval
    public let nudgeInterval: TimeInterval
    public private(set) var lastActivity: TimeInterval
    public private(set) var lastNudge: TimeInterval?

    public init(now: TimeInterval, idleThreshold: TimeInterval = 120, nudgeInterval: TimeInterval = 30) {
        self.idleThreshold = idleThreshold
        self.nudgeInterval = nudgeInterval
        self.lastActivity = now
    }

    public mutating func recordActivity(at now: TimeInterval) {
        lastActivity = now
        lastNudge = nil
    }

    public func idleDuration(at now: TimeInterval) -> TimeInterval {
        max(0, now - lastActivity)
    }

    public func shouldNudge(at now: TimeInterval, enabled: Bool, sessionActive: Bool,
                            permitted: Bool, buttonHeld: Bool) -> Bool {
        guard enabled, sessionActive, permitted, !buttonHeld,
              idleDuration(at: now) >= idleThreshold else { return false }
        return lastNudge.map { now - $0 >= nudgeInterval } ?? true
    }

    public mutating func recordNudge(at now: TimeInterval) {
        lastNudge = now
    }
}

public enum CursorGeometry {
    /// Quartz coordinates, including screens positioned left of or above the main display.
    public static func nudge(from point: CGPoint, within bounds: CGRect, distance: CGFloat = 2) -> CGPoint? {
        guard bounds.width > 1, bounds.height > 1, bounds.contains(point), distance > 0 else { return nil }
        let maxX = bounds.maxX - 1
        let right = point.x + distance
        let left = point.x - distance
        let x = right <= maxX ? right : max(bounds.minX, left)
        guard x != point.x else { return nil }
        return CGPoint(x: x, y: point.y)
    }

    public static func isNear(_ first: CGPoint, _ second: CGPoint, tolerance: CGFloat = 0.5) -> Bool {
        abs(first.x - second.x) <= tolerance && abs(first.y - second.y) <= tolerance
    }
}
