import Foundation

enum KeyboardLightTests {
    static func run() {
        let legacy = try! JSONDecoder().decode(Config.self, from: Data("{}".utf8))
        assert(!legacy.turnOffKeyboardLight, "an older config keeps the keyboard light on")
        assert(!Config.default.turnOffKeyboardLight, "GiGi leaves the keyboard light alone by default")
        var encoded = Config.default
        encoded.turnOffKeyboardLight = true
        let decoded = try! JSONDecoder().decode(Config.self, from: JSONEncoder().encode(encoded))
        assert(decoded.turnOffKeyboardLight, "the setting survives a round trip through the config")
        assert(encoded.sanitized().turnOffKeyboardLight, "sanitizing keeps the setting")

        var level = 0.6
        var written: [Double] = []
        let fake = KeyboardLight(
            identifiers: { [7] },
            read: { _ in level },
            write: { _, value in level = value; written.append(value); return true }
        )
        assert(fake.isSupported, "a keyboard that reports a level is controllable")
        assert(fake.current() == 0.6, "the current level is read back")
        assert(!KeyboardLight.unsupported.isSupported, "a Mac without a backlit keyboard is not controllable")
        assert(!KeyboardLight.unsupported.set(0), "writing an unsupported keyboard reports failure")

        var config = Config.default
        config.turnOffKeyboardLight = true
        config.idleThresholdSeconds = 1e9
        let engine = Engine(config: config)
        engine.keyboardLight = fake
        engine.mode = .always
        engine.start(reason: "keyboard light test")
        assert(engine.tick(), "the engine must keep running while the keyboard light is off")
        assert(written == [0], "an active engine turns the keyboard backlight off")
        assert(engine.status.keyboardLightOff, "the status reports the keyboard light as off")
        assert(engine.tick(), "a second tick must not rewrite the same level")
        assert(written == [0], "the backlight is written once per change, not on every tick")
        engine.stop(reason: "keyboard light test")
        assert(written == [0, 0.6], "stopping restores the level captured before turning it off")
        assert(!engine.status.keyboardLightOff, "a stopped engine is not holding the backlight off")

        level = 0.6
        written = []
        engine.start(reason: "keyboard light test")
        assert(engine.tick(), "the engine must keep running while the keyboard light is off")
        level = 0.25
        engine.stop(reason: "keyboard light test")
        assert(written == [0], "a backlight changed by hand is left alone when the engine stops")

        level = 0.6
        written = []
        var passive = Config.default
        passive.turnOffKeyboardLight = false
        passive.idleThresholdSeconds = 1e9
        let untouched = Engine(config: passive)
        untouched.keyboardLight = fake
        untouched.mode = .always
        untouched.start(reason: "keyboard light off")
        assert(untouched.tick(), "the engine must keep running with the keyboard light on")
        assert(written.isEmpty, "nothing is written while the setting is off")
        untouched.stop(reason: "keyboard light off")

        level = 0.6
        written = []
        var unsupportedConfig = config
        unsupportedConfig.idleThresholdSeconds = 1e9
        let limited = Engine(config: unsupportedConfig)
        limited.keyboardLight = .unsupported
        limited.mode = .always
        limited.start(reason: "unsupported keyboard test")
        assert(limited.tick(), "an uncontrollable keyboard must not stop the engine")
        assert(!limited.status.keyboardLightOff, "an uncontrollable keyboard is never reported as off")
        limited.stop(reason: "unsupported keyboard test")

        print("Keyboard backlight checks passed")
    }
}
