import Foundation

struct ScheduleWindow: Codable {
    var start: String
    var end: String
}

struct Schedule: Codable {
    var enabled: Bool
    var days: [String]
    var windows: [ScheduleWindow]
}

struct Config: Codable {
    var intervalSeconds: [Double]
    var idleThresholdSeconds: Double
    var jiggleDistancePixels: Double
    var preventDisplaySleep: Bool
    var wakeDisplayOnWindowStart: Bool
    var schedule: Schedule

    static let `default` = Config(
        intervalSeconds: [45, 90],
        idleThresholdSeconds: 40,
        jiggleDistancePixels: 2,
        preventDisplaySleep: true,
        wakeDisplayOnWindowStart: true,
        schedule: Schedule(
            enabled: false,
            days: ["mon", "tue", "wed", "thu", "fri"],
            windows: [ScheduleWindow(start: "09:00", end: "18:00")]
        )
    )

    func sanitized() -> Config {
        var config = self
        if config.intervalSeconds.count != 2
            || config.intervalSeconds[0] <= 0
            || config.intervalSeconds[1] < config.intervalSeconds[0] {
            config.intervalSeconds = Config.default.intervalSeconds
        }
        config.jiggleDistancePixels = max(0, config.jiggleDistancePixels)
        config.idleThresholdSeconds = max(0, config.idleThresholdSeconds)
        return config
    }
}

func defaultConfigURL() -> URL {
    FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/gigi/config.json")
}

func saveConfig(_ config: Config, path: String? = nil) -> Bool {
    let url = path.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) } ?? defaultConfigURL()
    do {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(config).write(to: url, options: .atomic)
        Log.info("config: wrote \(url.path)")
        return true
    } catch {
        Log.error("config: cannot write \(url.path): \(error.localizedDescription)")
        return false
    }
}

func loadConfig(path: String?) -> Config {
    let url = path.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) } ?? defaultConfigURL()
    guard FileManager.default.fileExists(atPath: url.path) else {
        Log.info("config: missing \(url.path), using defaults")
        return .default
    }
    do {
        let data = try Data(contentsOf: url)
        let config = try JSONDecoder().decode(Config.self, from: data).sanitized()
        Log.info("config: loaded \(url.path)")
        return config
    } catch {
        Log.error("config: cannot read \(url.path): \(error.localizedDescription)")
        Log.info("config: using defaults")
        return .default
    }
}
