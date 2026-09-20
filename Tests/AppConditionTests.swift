import Foundation

enum AppConditionTests {
    static func run() {
        let finder = SelectedApp(id: "com.apple.finder", name: "Finder")
        let terminal = SelectedApp(id: "com.apple.Terminal", name: "Terminal")
        let safari = "com.apple.Safari"

        let disabled = AppCondition(enabled: false, mode: "frontmost", apps: [finder])
        assert(disabled.allows(AppActivity()), "a disabled condition allows activity with nothing running")
        assert(disabled.allows(AppActivity(running: [terminal.id], frontmost: terminal.id)),
               "a disabled condition ignores the watched apps")

        var running = AppCondition()
        running.enabled = true
        running.apps = [finder]
        assert(running.allows(AppActivity(running: [finder.id], frontmost: safari)),
               "running mode allows activity while the watched app is in the background")
        assert(!running.allows(AppActivity(running: [safari], frontmost: safari)),
               "running mode does not fall back to the frontmost app")
        assert(!running.allows(AppActivity()), "nothing running means no activity")

        var frontmost = AppCondition()
        frontmost.enabled = true
        frontmost.mode = "frontmost"
        frontmost.apps = [finder, terminal]
        assert(frontmost.allows(AppActivity(running: [finder.id], frontmost: finder.id)),
               "the watched app in front allows activity")
        assert(frontmost.allows(AppActivity(running: [finder.id, terminal.id], frontmost: terminal.id)),
               "either watched app can be the one in front")
        assert(!frontmost.allows(AppActivity(running: [finder.id], frontmost: safari)),
               "another app in front blocks activity even with a watched app running")
        assert(!frontmost.allows(AppActivity(running: [finder.id])),
               "no frontmost application means no activity")

        var empty = AppCondition()
        empty.enabled = true
        empty.apps = []
        assert(empty.allows(AppActivity(running: [finder.id], frontmost: finder.id)),
               "an enabled condition without apps must not block activity")

        var config = Config.default
        config.appCondition = AppCondition(enabled: true, mode: "whenever",
                                           apps: [finder, finder, SelectedApp(id: "", name: "Ghost")])
        let clean = config.sanitized().appCondition
        assert(clean.mode == "running", "an unknown mode falls back to running")
        assert(clean.apps == [finder], "the app list is deduplicated and empty identifiers are dropped")

        config.appCondition = frontmost
        let decoded = try! JSONDecoder().decode(Config.self, from: JSONEncoder().encode(config)).appCondition
        assert(decoded.enabled && decoded.mode == "frontmost" && decoded.apps == [finder, terminal],
               "the condition round-trips through the configuration file")

        let legacy = try! JSONDecoder().decode(Config.self, from: Data("{}".utf8)).appCondition
        assert(!legacy.enabled && legacy.mode == "running" && legacy.apps.isEmpty,
               "a configuration written before the condition existed keeps it off")

        var gated = Config.default
        gated.appCondition = running
        gated.idleThresholdSeconds = 1e9
        let engine = Engine(config: gated)
        engine.mode = .always
        engine.readAppActivity = { AppActivity() }
        engine.start(reason: "app condition test")
        assert(engine.tick(), "waiting for an app keeps the engine running")
        assert(engine.status.waitingForApp, "the status reports the wait")
        assert(!engine.status.displayAssertion, "waiting for an app releases the display assertion")
        assert(!engine.status.outOfSchedule, "an app condition is not an out of schedule state")
        assert(engine.shortStatus == L("Waiting for selected app"), "the panel shows why it is not moving")
        assert(engine.statusLine().contains("waiting-for-app"), "the CLI must not claim the engine is active")
        engine.readAppActivity = { AppActivity(running: [finder.id], frontmost: safari) }
        assert(engine.tick(), "the engine keeps running once the app shows up")
        assert(!engine.status.waitingForApp && engine.status.displayAssertion,
               "activity resumes with the app and the display assertion comes back")
        engine.readAppActivity = { AppActivity() }
        assert(engine.tick() && !engine.status.displayAssertion,
               "the assertion is released again when the app quits")
        engine.stop(reason: "app condition test")

        var ungated = Config.default
        ungated.appCondition = empty
        ungated.idleThresholdSeconds = 1e9
        let open = Engine(config: ungated)
        open.mode = .always
        open.readAppActivity = { AppActivity() }
        open.start(reason: "empty app list test")
        assert(open.tick() && open.status.displayAssertion,
               "an enabled condition without apps keeps the display awake")
        open.stop(reason: "empty app list test")

        print("App condition checks passed")
    }
}
