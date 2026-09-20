import Foundation

enum NoticeTests {
    static func run() {
        var center = NoticeCenter()
        var posted: [Notice] = []
        center.post = { posted.append($0) }
        center.offer(.timerExpired)
        center.offer(.timerExpired)
        assert(posted == [.timerExpired], "a notice is delivered once per session")
        center.beginSession()
        center.offer(.timerExpired)
        assert(posted == [.timerExpired, .timerExpired], "a new session can raise the same notice again")
        center.offer(.batteryStop(percent: 20, limit: 25))
        center.offer(.batteryStop(percent: 19, limit: 25))
        assert(posted.count == 3, "the battery stop is delivered once per session, whatever the reading")
        center.beginSession()
        center.offer(.missingAccessibility)
        center.beginSession()
        center.offer(.missingAccessibility)
        assert(posted.count == 4, "the permission notice is delivered only once per run")
        center.enabled = false
        center.beginSession()
        center.offer(.timerExpired)
        assert(posted.count == 4, "a disabled notice center stays silent")

        let legacy = try! JSONDecoder().decode(Config.self, from: Data("{}".utf8))
        assert(legacy.notificationsEnabled, "notifications are on by default")
        var off = Config.default
        off.notificationsEnabled = false
        let decoded = try! JSONDecoder().decode(Config.self, from: JSONEncoder().encode(off))
        assert(!decoded.notificationsEnabled, "the notification switch round-trips through the configuration file")

        var config = Config.default
        config.batteryLimitEnabled = true
        config.batteryLimitPercent = 20
        config.idleThresholdSeconds = 1e9
        let engine = Engine(config: config)
        var fired: [Notice] = []
        engine.notices.post = { fired.append($0) }
        engine.isAccessibilityTrusted = { true }
        engine.mode = .always
        engine.start(reason: "notice test")
        assert(fired.isEmpty, "starting the engine raises nothing")
        engine.setDeadline(Date().addingTimeInterval(-1))
        assert(!engine.tick(), "an expired timer stops the engine")
        assert(fired == [.timerExpired], "the timer expiry raises a notice")
        engine.setDeadline(nil)
        var toggled = config
        toggled.notificationsEnabled = false
        engine.apply(config: toggled)
        assert(!engine.notices.enabled, "reloading a configuration with the switch off silences the notices")
        engine.start(reason: "notice test")
        engine.setDeadline(Date().addingTimeInterval(-1))
        assert(!engine.tick() && fired == [.timerExpired], "a silenced engine raises nothing")

        var low = config
        low.batteryLimitPercent = 20
        let batteryEngine = Engine(config: low)
        var batteryNotices: [Notice] = []
        batteryEngine.notices.post = { batteryNotices.append($0) }
        batteryEngine.isAccessibilityTrusted = { true }
        batteryEngine.readBattery = { BatteryState(percent: 18, onBattery: true) }
        batteryEngine.start(reason: "notice test")
        assert(!batteryEngine.tick(), "the battery limit stops the engine")
        assert(batteryNotices == [.batteryStop(percent: 18, limit: 20)],
               "the battery notice carries the reading and the limit")
        assert(batteryEngine.tick() && batteryNotices.count == 1, "the battery stop is not repeated")

        var blocked = Config.default
        blocked.idleThresholdSeconds = 0
        blocked.intervalSeconds = [1, 1]
        let denied = Engine(config: blocked)
        var deniedNotices: [Notice] = []
        var prompted = 0
        denied.notices.post = { deniedNotices.append($0) }
        denied.isAccessibilityTrusted = { false }
        denied.requestAccessibilityPermission = { prompted += 1 }
        denied.mode = .always
        denied.start(reason: "notice test")
        assert(denied.tick(), "a missing permission keeps the engine running")
        assert(deniedNotices == [.missingAccessibility], "a missing permission raises a notice")
        assert(prompted == 1, "the system prompt is asked for once")
        assert(!denied.status.accessibilityTrusted, "the status reports the missing permission")
        assert(denied.tick() && deniedNotices.count == 1 && prompted == 1,
               "the permission notice is not repeated on every tick")
        denied.stop(reason: "notice test")

        print("Notice checks passed")
    }
}
