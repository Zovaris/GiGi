import Foundation

enum RestoreTests {
    static func run() {
        assert(overridesURL().lastPathComponent == "overrides.json", "the record lives next to the config")
        assert(overridesURL(configPath: "/tmp/gigi-config/custom.json").path == "/tmp/gigi-config/overrides.json",
               "a custom config keeps its record in the same folder")
        let overrides = Overrides(displayApplied: 0.3, displayOriginal: 0.8,
                                  keyboardApplied: 0, keyboardOriginal: 0.6)
        assert(Overrides().isEmpty, "an empty record holds nothing")
        assert(!overrides.isEmpty, "a record with a taken value is not empty")
        let decoded = try! JSONDecoder().decode(Overrides.self, from: JSONEncoder().encode(overrides))
        assert(decoded == overrides, "the record survives a round trip through JSON")

        var saved: Overrides?
        var clears = 0
        let store = OverrideStore(load: { saved }, save: { saved = $0 }, clear: { saved = nil; clears += 1 })

        var level = 0.8
        var light = 0.6
        let display = Brightness(read: { _ in level }, write: { _, value in level = value; return true })
        let keyboard = KeyboardLight(identifiers: { [1] }, read: { _ in light },
                                     write: { _, value in light = value; return true })

        var config = Config.default
        config.dimWhileActive = true
        config.dimBrightness = 0.3
        config.turnOffKeyboardLight = true
        config.idleThresholdSeconds = 1e9

        func engineWithRecord() -> Engine {
            let engine = Engine(config: config)
            engine.brightness = display
            engine.keyboardLight = keyboard
            engine.overrides = store
            engine.mode = .always
            return engine
        }

        let clean = engineWithRecord()
        clean.start(reason: "restore test")
        assert(clean.tick(), "the engine must keep running")
        assert(level == 0.3 && light == 0, "an active engine dims the display and turns the light off")
        assert(saved?.displayApplied == 0.3 && saved?.displayOriginal == 0.8,
               "the display level and the one it replaced are written down")
        assert(saved?.keyboardApplied == 0 && saved?.keyboardOriginal == 0.6,
               "the keyboard level and the one it replaced are written down")
        clean.stop(reason: "restore test")
        assert(level == 0.8 && light == 0.6, "a clean stop puts both values back")
        assert(saved?.isEmpty ?? true, "a clean stop leaves nothing to repair")
        assert(clears > 0, "the record is dropped when the last value is released")

        let orphan = engineWithRecord()
        orphan.start(reason: "restore test")
        assert(orphan.tick(), "the engine must keep running")
        assert(level == 0.3 && light == 0, "the engine holds both values before the crash")
        level = 0.55
        light = 0.4
        let repaired = engineWithRecord()
        repaired.recoverOverrides()
        assert(level == 0.55 && light == 0.4, "a value changed by hand after the crash is left alone")
        assert(saved == nil, "the record is dropped once it has been looked at")

        level = 0.8
        light = 0.6
        let second = engineWithRecord()
        second.start(reason: "restore test")
        assert(second.tick(), "the engine must keep running")
        assert(level == 0.3 && light == 0, "the engine holds both values again")
        let next = engineWithRecord()
        next.recoverOverrides()
        assert(level == 0.8 && light == 0.6, "the next launch repairs the values an unclean exit left behind")
        assert(saved == nil, "the repair clears the record")

        let idle = engineWithRecord()
        idle.recoverOverrides()
        assert(level == 0.8 && light == 0.6, "a launch with nothing written down changes nothing")
        idle.stop(reason: "restore test")

        print("Override record checks passed")
    }
}
