import Foundation

@main
struct TimerTests {
    static func main() {
        let engine = Engine(config: .default)
        let now = Date()
        engine.start(reason: "timer test")
        engine.setDeadline(now.addingTimeInterval(-1))
        assert(!engine.tick(now: now), "An expired timer must signal completion")
        assert(!engine.running, "Expiry must stop the engine")
        assert(engine.status.deadline == nil, "Expiry must clear the active deadline")
        assert(!engine.status.displayAssertion, "Expiry must release the display")
        engine.setDeadline(now.addingTimeInterval(60))
        engine.start(reason: "restart test")
        assert(engine.running && engine.status.deadline != nil, "A new session can rearm the timer")
        engine.stop(reason: "test complete")
        engine.setDeadline(nil)
        assert(engine.tick(now: now), "A cleared timer must not expire again")
        print("Timer lifecycle checks passed")
    }
}
