import Foundation
import IOKit.pwr_mgt

final class PowerAssertions {
    private var displayAssertion: IOPMAssertionID = 0
    private(set) var hasDisplayAssertion = false

    func startDisplayAssertion() {
        guard !hasDisplayAssertion else { return }
        var id: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "GiGi: display idle" as CFString,
            &id
        )
        if result == kIOReturnSuccess {
            displayAssertion = id
            hasDisplayAssertion = true
            Log.info("display: assertion ACTIVE (display will not sleep on idle)")
        } else {
            Log.error("display: could not create assertion (IOReturn \(result))")
        }
    }

    func stopDisplayAssertion() {
        guard hasDisplayAssertion else { return }
        IOPMAssertionRelease(displayAssertion)
        displayAssertion = 0
        hasDisplayAssertion = false
        Log.info("display: assertion released")
    }

    func declareUserActivity() {
        var id: IOPMAssertionID = 0
        let result = IOPMAssertionDeclareUserActivity(
            "GiGi: user active" as CFString,
            kIOPMUserActiveLocal,
            &id
        )
        if result == kIOReturnSuccess {
            Log.info("display: user activity declared (wakes the display)")
            IOPMAssertionRelease(id)
        } else {
            Log.error("display: declareUserActivity failed (IOReturn \(result))")
        }
    }
}
