import Foundation

struct ScheduleWindow: Codable, Equatable {
    var start: String
    var end: String
}

struct Schedule: Codable, Equatable {
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
    var clickMode: String
    var scrollMode: String
    var dimWhileActive: Bool
    var dimBrightness: Double
    var batteryLimitEnabled: Bool
    var batteryLimitPercent: Int
    var hotkey: String
    var schedule: Schedule

    static let clickModes = ["none", "single", "double", "right"]
    static let scrollModes = ["none", "ping", "down", "up"]
    static let batteryLimitChoices = [5, 10, 15, 20, 25, 30]

    static let `default` = Config(
        intervalSeconds: [45, 90],
        idleThresholdSeconds: 40,
        jiggleDistancePixels: 2,
        preventDisplaySleep: true,
        wakeDisplayOnWindowStart: true,
        clickMode: "none",
        scrollMode: "none",
        dimWhileActive: false,
        dimBrightness: 0.35,
        batteryLimitEnabled: false,
        batteryLimitPercent: 20,
        hotkey: Hotkey.default.config,
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
        if !Config.clickModes.contains(config.clickMode) { config.clickMode = "none" }
        if !Config.scrollModes.contains(config.scrollMode) { config.scrollMode = "none" }
        config.dimBrightness = min(1, max(0.05, config.dimBrightness.isFinite ? config.dimBrightness : 0.35))
        if config.hotkey != Hotkey.disabledName && Hotkey.parse(config.hotkey) == nil {
            config.hotkey = Config.default.hotkey
        }
        config.batteryLimitPercent = min(100, max(1, config.batteryLimitPercent))
        let selected = Set(config.schedule.days.map { $0.lowercased() })
        config.schedule.days = weekdayNames.filter { selected.contains($0) }
        return config
    }
}

extension Config {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = Config.default
        intervalSeconds = try container.decodeIfPresent([Double].self, forKey: .intervalSeconds) ?? fallback.intervalSeconds
        idleThresholdSeconds = try container.decodeIfPresent(Double.self, forKey: .idleThresholdSeconds) ?? fallback.idleThresholdSeconds
        jiggleDistancePixels = try container.decodeIfPresent(Double.self, forKey: .jiggleDistancePixels) ?? fallback.jiggleDistancePixels
        preventDisplaySleep = try container.decodeIfPresent(Bool.self, forKey: .preventDisplaySleep) ?? fallback.preventDisplaySleep
        wakeDisplayOnWindowStart = try container.decodeIfPresent(Bool.self, forKey: .wakeDisplayOnWindowStart) ?? fallback.wakeDisplayOnWindowStart
        clickMode = try container.decodeIfPresent(String.self, forKey: .clickMode) ?? fallback.clickMode
        scrollMode = try container.decodeIfPresent(String.self, forKey: .scrollMode) ?? fallback.scrollMode
        dimWhileActive = try container.decodeIfPresent(Bool.self, forKey: .dimWhileActive) ?? fallback.dimWhileActive
        dimBrightness = try container.decodeIfPresent(Double.self, forKey: .dimBrightness) ?? fallback.dimBrightness
        batteryLimitEnabled = try container.decodeIfPresent(Bool.self, forKey: .batteryLimitEnabled) ?? fallback.batteryLimitEnabled
        batteryLimitPercent = try container.decodeIfPresent(Int.self, forKey: .batteryLimitPercent) ?? fallback.batteryLimitPercent
        hotkey = try container.decodeIfPresent(String.self, forKey: .hotkey) ?? fallback.hotkey
        schedule = try container.decodeIfPresent(Schedule.self, forKey: .schedule) ?? fallback.schedule
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
