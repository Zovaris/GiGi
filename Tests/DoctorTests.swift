import Foundation

enum DoctorTests {
    static func run() {
        assert(ConfigInspection.loaded(.default) == .loaded(.default), "a loaded config compares by value")
        assert(ConfigInspection.missing != .invalid("boom"), "the inspection cases stay distinct")

        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("gigi-doctor-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let path = folder.appendingPathComponent("config.json").path
        defer { try? FileManager.default.removeItem(at: folder) }

        assert(inspectConfig(path: path) == .missing, "a missing file is reported as missing")

        try? Data("{ not json".utf8).write(to: URL(fileURLWithPath: path))
        if case .invalid = inspectConfig(path: path) {} else {
            assertionFailure("unreadable json must be reported as invalid")
        }

        var config = Config.default
        config.batteryLimitPercent = 35
        try? JSONEncoder().encode(config).write(to: URL(fileURLWithPath: path))
        guard case .loaded(let loaded) = inspectConfig(path: path) else {
            assertionFailure("a written config must load back")
            return
        }
        assert(loaded.batteryLimitPercent == 35, "the loaded config carries the values in the file")
        assert(loaded == config.sanitized(), "the loaded config is sanitized")

        assert(configWarnings(Config.default).isEmpty, "the default config has nothing to warn about")

        var dim = Config.default
        dim.dimWhileActive = true
        dim.preventDisplaySleep = false
        assert(configWarnings(dim).count == 1, "dimming without the display assertion is reported")

        var emptyDays = Config.default
        emptyDays.schedule.enabled = true
        emptyDays.schedule.days = []
        assert(configWarnings(emptyDays).contains { $0.contains("never activates") },
               "a schedule without a weekday never activates")

        var emptyWindows = Config.default
        emptyWindows.schedule.enabled = true
        emptyWindows.schedule.windows = []
        assert(configWarnings(emptyWindows).contains { $0.contains("limits nothing") },
               "a schedule without a window limits nothing")

        var noApps = Config.default
        noApps.appCondition.enabled = true
        noApps.appCondition.apps = []
        assert(configWarnings(noApps).contains { $0.contains("no app is selected") },
               "an app condition without an app allows everything")

        var noisy = Config.default
        noisy.dimWhileActive = true
        noisy.preventDisplaySleep = false
        noisy.schedule.enabled = true
        noisy.schedule.days = []
        noisy.appCondition.enabled = true
        assert(configWarnings(noisy).count == 3, "every problem in the config is reported once")

        assert(configWarnings(Config.default.sanitized()).isEmpty, "a sanitized default stays quiet")

        print("Doctor checks passed")
    }
}
