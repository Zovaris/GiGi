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

        for name in ["control", "cmd", "shift", "opt"] {
            let combo = "\(name)+j"
            guard let hotkey = Hotkey.parse(combo) else {
                assertionFailure("\(combo) must parse")
                continue
            }
            assert(Hotkey.parse(hotkey.config) == hotkey, "\(combo) must round-trip through its config text")
            assert(!hotkey.display.isEmpty, "\(combo) must have a display form")
        }
        assert(Hotkey.parse("j")?.modifiers == 0, "a bare key is allowed for the recorder")
        assert(Hotkey.parse("ctrl+cmd+j")?.display == "⌃⌘J", "control and command render in Apple order")
        assert(Hotkey.parse("hyper+j") == nil, "an unknown modifier must not parse")
        assert(Hotkey.parse("ctrl+") == nil, "a missing key must not parse")
        assert(Hotkey.from(keyCode: 250, modifiers: 0) == nil, "an unknown key code must not resolve")
        assert(Config.default.hotkey == Hotkey.default.config, "the default config carries the default shortcut")

        var invalid = Config.default
        invalid.clickMode = "triple"
        invalid.scrollMode = "sideways"
        invalid.hotkey = "hyper+9"
        let repaired = invalid.sanitized()
        assert(repaired.clickMode == "none", "an unknown click mode falls back to none")
        assert(repaired.scrollMode == "none", "an unknown scroll mode falls back to none")
        assert(repaired.hotkey == Config.default.hotkey, "an unparsable shortcut falls back to the default")

        print("Timer lifecycle, hotkey and config checks passed")
    }
}
