import Foundation

enum WakeTests {
    static func run() {
        var level = 0.8
        var written: [Double] = []
        let display = Brightness(
            read: { _ in level },
            write: { _, value in level = value; written.append(value); return true }
        )
        var light = 0.6
        var lightWritten: [Double] = []
        let keyboard = KeyboardLight(
            identifiers: { [1] },
            read: { _ in light },
            write: { _, value in light = value; lightWritten.append(value); return true }
        )

        var config = Config.default
        config.dimWhileActive = true
        config.dimBrightness = 0.3
        config.turnOffKeyboardLight = true
        config.idleThresholdSeconds = 1e9

        var uptime: TimeInterval = 1000
        let engine = Engine(config: config)
        engine.brightness = display
        engine.keyboardLight = keyboard
        engine.readUptime = { uptime }
        engine.mode = .always
        engine.start(reason: "wake test")

        let start = Date()
        assert(engine.tick(now: start), "the engine must keep running")
        assert(written == [0.3], "an active engine dims the display")
        assert(lightWritten == [0], "an active engine turns the keyboard light off")

        uptime += 1
        assert(engine.tick(now: start.addingTimeInterval(1)), "the engine must keep running")
        assert(written == [0.3] && lightWritten == [0], "a plain tick does not rewrite the same values")

        uptime += 1
        assert(engine.tick(now: start.addingTimeInterval(2)), "the engine must keep running")
        assert(written == [0.3] && lightWritten == [0], "a slow tick is not a wake")

        uptime += 1
        assert(engine.tick(now: start.addingTimeInterval(3602)), "the engine must keep running")
        assert(written == [0.3, 0.3], "after a wake the display is dimmed again")
        assert(lightWritten == [0, 0], "after a wake the keyboard light goes off again")

        engine.stop(reason: "wake test")
        assert(written == [0.3, 0.3, 0.8], "the level captured before the sleep is the one restored")
        assert(lightWritten == [0, 0, 0.6], "the keyboard level captured before the sleep is the one restored")

        var dimOnly = Config.default
        dimOnly.dimWhileActive = false
        dimOnly.idleThresholdSeconds = 1e9
        var quietUptime: TimeInterval = 500
        let untouched = Engine(config: dimOnly)
        untouched.brightness = Brightness(read: { _ in 0.5 }, write: { _, _ in true })
        untouched.keyboardLight = keyboard
        untouched.readUptime = { quietUptime }
        untouched.mode = .always
        untouched.start(reason: "wake test")
        lightWritten = []
        assert(untouched.tick(now: Date()), "the engine must keep running")
        quietUptime += 1
        assert(untouched.tick(now: Date().addingTimeInterval(3600)), "the engine must keep running")
        assert(lightWritten.isEmpty, "a wake must not touch a keyboard light that is left alone")
        untouched.stop(reason: "wake test")

        print("Wake re-apply checks passed")
    }
}
