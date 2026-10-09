import Foundation
import IOKit.pwr_mgt

@MainActor
final class PowerAssertions {
    private var displayID: IOPMAssertionID = 0
    private var systemID: IOPMAssertionID = 0
    private var activityID: IOPMAssertionID = 0
    private(set) var lastError: String?

    var isActive: Bool { displayID != 0 && systemID != 0 }

    @discardableResult
    func start() -> Bool {
        if isActive { return true }
        stop()
        lastError = nil
        let displayResult = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "NoLock: keep the display awake" as CFString, &displayID)
        let systemResult = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "NoLock: keep ongoing work running" as CFString, &systemID)
        guard displayResult == kIOReturnSuccess, systemResult == kIOReturnSuccess else {
            lastError = "macOS could not enable sleep prevention (\(displayResult), \(systemResult))."
            stop()
            return false
        }
        return true
    }

    /// A separate user-activity pulse supplements power assertions for idle timers.
    @discardableResult
    func declareActivity() -> Bool {
        let result = IOPMAssertionDeclareUserActivity(
            "NoLock: ongoing work" as CFString, kIOPMUserActiveLocal, &activityID)
        if result != kIOReturnSuccess {
            lastError = "macOS could not refresh user activity (\(result))."
        }
        return result == kIOReturnSuccess
    }

    func stop() {
        for id in [displayID, systemID, activityID] where id != 0 {
            IOPMAssertionRelease(id)
        }
        displayID = 0
        systemID = 0
        activityID = 0
    }
}
