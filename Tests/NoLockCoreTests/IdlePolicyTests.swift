import Foundation
import CoreGraphics
import Testing
@testable import NoLockCore

@Test func waitsTwoMinutesThenRepeatsEveryThirtySeconds() {
    var policy = IdlePolicy(now: 100)
    func due(_ time: TimeInterval) -> Bool {
        policy.shouldNudge(at: time, enabled: true, sessionActive: true, permitted: true, buttonHeld: false)
    }
    #expect(!due(219.99))
    #expect(due(220))
    policy.recordNudge(at: 220)
    #expect(!due(249.99))
    #expect(due(250))
    #expect(policy.idleDuration(at: 250) == 150)
}

@Test func realInputRestartsTheFullIdleCountdown() {
    var policy = IdlePolicy(now: 0)
    policy.recordNudge(at: 120)
    policy.recordActivity(at: 140)
    #expect(policy.lastNudge == nil)
    #expect(!policy.shouldNudge(at: 259, enabled: true, sessionActive: true, permitted: true, buttonHeld: false))
    #expect(policy.shouldNudge(at: 260, enabled: true, sessionActive: true, permitted: true, buttonHeld: false))
}

@Test func neverMovesWithoutPermissionOrDuringDragsOrInactiveSessions() {
    let policy = IdlePolicy(now: 0)
    #expect(!policy.shouldNudge(at: 500, enabled: false, sessionActive: true, permitted: true, buttonHeld: false))
    #expect(!policy.shouldNudge(at: 500, enabled: true, sessionActive: false, permitted: true, buttonHeld: false))
    #expect(!policy.shouldNudge(at: 500, enabled: true, sessionActive: true, permitted: false, buttonHeld: false))
    #expect(!policy.shouldNudge(at: 500, enabled: true, sessionActive: true, permitted: true, buttonHeld: true))
}

@Test func staysInsideEachDisplayIncludingNegativeCoordinates() {
    let main = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    #expect(CursorGeometry.nudge(from: CGPoint(x: 1919, y: 500), within: main) == CGPoint(x: 1917, y: 500))
    #expect(CursorGeometry.nudge(from: CGPoint(x: 0, y: 0), within: main) == CGPoint(x: 2, y: 0))
    let left = CGRect(x: -1920, y: -200, width: 1920, height: 1080)
    #expect(CursorGeometry.nudge(from: CGPoint(x: -1, y: -100), within: left) == CGPoint(x: -3, y: -100))
    #expect(CursorGeometry.nudge(from: CGPoint(x: -1920, y: -200), within: left) == CGPoint(x: -1918, y: -200))
    #expect(CursorGeometry.nudge(from: CGPoint(x: 2000, y: 0), within: main) == nil)
    #expect(CursorGeometry.nudge(from: .zero, within: .zero) == nil)
}

@Test func monotonicClockAndReturnTolerance() {
    let policy = IdlePolicy(now: 100)
    #expect(policy.idleDuration(at: 90) == 0)
    #expect(CursorGeometry.isNear(CGPoint(x: 100, y: 100), CGPoint(x: 100.25, y: 100)))
    #expect(!CursorGeometry.isNear(CGPoint(x: 100, y: 100), CGPoint(x: 101, y: 100)))
}
