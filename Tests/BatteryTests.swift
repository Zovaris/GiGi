import Foundation

enum BatteryTests {
    static func run() {
        let legacy = try! JSONDecoder().decode(Config.self, from: Data("{}".utf8))
        assert(!legacy.batteryLimitEnabled && legacy.batteryLimitPercent == 20)
        var config = Config.default
        config.batteryLimitEnabled = true
        config.batteryLimitPercent = -1
        assert(config.sanitized().batteryLimitPercent == 1)
        config.batteryLimitPercent = 200
        assert(config.sanitized().batteryLimitPercent == 100)
        assert(Config.batteryLimitChoices.contains(Config.default.batteryLimitPercent),
               "the default threshold must be one the panel offers")
        assert(Config.batteryLimitChoices.allSatisfy { $0 >= 5 && $0 <= 30 },
               "the offered thresholds stay inside the useful range")
        var handEdited = Config.default
        handEdited.batteryLimitPercent = 45
        assert(handEdited.sanitized().batteryLimitPercent == 45,
               "a threshold written in the file survives even when the panel does not offer it")
        config.batteryLimitPercent = 20
        config.preventDisplaySleep = false
        config.idleThresholdSeconds = 1e9
        let decoded = try! JSONDecoder().decode(Config.self, from: JSONEncoder().encode(config))
        assert(decoded.batteryLimitEnabled && decoded.batteryLimitPercent == 20)
        for mode in [Engine.Mode.schedule, .always] {
            for (reading, shouldStop) in [
                (BatteryState(percent: 20, onBattery: true), true),
                (BatteryState(percent: 19, onBattery: true), true),
                (BatteryState(percent: 21, onBattery: true), false),
                (BatteryState(percent: 10, onBattery: false), false),
                (nil, false)
            ] as [(BatteryState?, Bool)] {
                let engine = Engine(config: config)
                engine.mode = mode
                engine.readBattery = { reading }
                engine.start(reason: "battery test")
                engine.setDeadline(Date().addingTimeInterval(600))
                assert(engine.tick() == !shouldStop)
                assert(engine.running == !shouldStop)
                if shouldStop {
                    assert(engine.status.batteryStopped)
                    assert(engine.status.deadline == nil)
                    assert(!engine.status.displayAssertion)
                    engine.readBattery = { BatteryState(percent: 80, onBattery: false) }
                    assert(engine.tick() && !engine.running, "Plugging in must not restart GiGi")
                }
                engine.stop(reason: "test cleanup")
            }
        }
        config.batteryLimitEnabled = false
        let disabled = Engine(config: config)
        disabled.readBattery = { BatteryState(percent: 1, onBattery: true) }
        disabled.start(reason: "battery limit disabled")
        assert(disabled.tick() && disabled.running)
        disabled.stop(reason: "test cleanup")
        print("Battery limit checks passed")
    }

}
