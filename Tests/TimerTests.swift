import Foundation

@main
struct TimerTests {
    static func main() {
        BatteryTests.run()
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

        var messy = Config.default
        messy.schedule.days = ["MON", "mon", "fry", "sun"]
        assert(messy.sanitized().schedule.days == ["sun", "mon"],
               "day names are lowercased, deduplicated and put in week order")

        for raw in ["09:00", "00:00", "23:59", "7:05"] {
            guard let date = date(fromHM: raw) else {
                assertionFailure("\(raw) must parse into a date")
                continue
            }
            let formatted = timeString(from: date)
            assert(parseHM(formatted) != nil, "\(raw) must format back into a parsable time")
            assert(formatted == String(format: "%02d:%02d", parseHM(raw)!.h, parseHM(raw)!.m),
                   "\(raw) must round-trip through the config format")
        }
        assert(date(fromHM: "24:00") == nil, "an out-of-range hour must not parse")
        assert(date(fromHM: "9h00") == nil, "a malformed time must not parse")
        assert(timeString(from: date(fromHM: "18:30")!) == "18:30", "the formatter keeps the 24 hour shape")

        var level = 0.8
        var written: [Double] = []
        let fake = Brightness(
            read: { _ in level },
            write: { _, value in level = value; written.append(value); return true }
        )
        var dimConfig = Config.default
        dimConfig.dimWhileActive = true
        dimConfig.dimBrightness = 0.3
        dimConfig.idleThresholdSeconds = 1e9
        let dimmer = Engine(config: dimConfig)
        dimmer.brightness = fake
        dimmer.mode = .always
        dimmer.start(reason: "brightness test")
        assert(dimmer.tick(), "the engine must keep running while dimming")
        assert(written == [0.3], "an active engine dims the display to the configured level")
        assert(dimmer.status.dimmed, "the status must report the display as dimmed")
        assert(dimmer.tick(), "a second tick must not rewrite the same brightness")
        assert(written == [0.3], "the brightness is written once per change, not on every tick")
        dimmer.stop(reason: "brightness test")
        assert(written == [0.3, 0.8], "stopping restores the brightness captured before dimming")
        assert(!dimmer.status.dimmed, "a stopped engine is not dimming anything")

        level = 0.8
        written = []
        dimmer.start(reason: "brightness test")
        assert(dimmer.tick(), "the engine must keep running while dimming")
        level = 0.55
        dimmer.stop(reason: "brightness test")
        assert(written == [0.3], "a brightness changed by hand is left alone when the engine stops")

        level = 0.8
        written = []
        var noAssert = dimConfig
        noAssert.preventDisplaySleep = false
        let bare = Engine(config: noAssert)
        bare.brightness = fake
        bare.mode = .always
        bare.start(reason: "brightness test")
        assert(bare.tick(), "the engine must keep running without the display assertion")
        assert(written.isEmpty, "nothing is dimmed when GiGi does not keep the display awake")
        bare.stop(reason: "brightness test")

        var gated = Config.default
        gated.schedule = Schedule(enabled: true, days: weekdayNames,
                                  windows: [ScheduleWindow(start: "09:00", end: "10:00")])
        gated.idleThresholdSeconds = 1e9
        let noon = date(fromHM: "12:00")!
        let gatedEngine = Engine(config: gated)
        gatedEngine.start(reason: "schedule test")
        assert(gatedEngine.tick(now: noon), "the engine must keep running outside its window")
        assert(!gatedEngine.status.displayAssertion, "outside the window the display assertion is released")
        gatedEngine.mode = .always
        assert(gatedEngine.tick(now: noon), "the engine must keep running while Mode is Always")
        assert(gatedEngine.status.displayAssertion, "Mode Always ignores the window and keeps the display awake")
        gatedEngine.stop(reason: "schedule test")

        var ungated = Config.default
        ungated.schedule.enabled = false
        ungated.schedule.windows = [ScheduleWindow(start: "09:00", end: "10:00")]
        assert(ungated.schedule.allows(noon), "a disabled schedule allows every hour")
        assert(gated.schedule.allows(noon) == false, "an enabled schedule keeps its hours")

        if let level = Brightness.system.current() {
            assert((0...1).contains(level), "a readable brightness must sit inside 0...1")
            assert(Brightness.system.isSupported, "a readable brightness means the display is controllable")
        }

        print("Timer lifecycle, hotkey and config checks passed")
    }
}
