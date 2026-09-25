import Foundation
import CoreGraphics

final class Engine {
    enum Mode: String {
        case schedule
        case always
    }

    struct Status {
        var batteryStopped: Bool = false
        var running: Bool = false
        var windowActive: Bool = false
        var jiggles: Int = 0
        var lastJiggle: Date?
        var lastIdle: Double?
        var displayAssertion: Bool = false
        var dimmed: Bool = false
        var brightness: Double?
        var keyboardLightOff: Bool = false
        var keyboardBrightness: Double?
        var waitingForApp: Bool = false
        var outOfSchedule: Bool = false
        var deadline: Date?
        var nextTransition: Date?
        var accessibilityTrusted: Bool = false
    }

    private(set) var config: Config
    private let power = PowerAssertions()
    var brightness: Brightness = .system
    var keyboardLight: KeyboardLight = .system
    var overrides: OverrideStore = .disabled
    var readAppActivity: () -> AppActivity = AppActivity.current
    var readUptime: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    private var waitingForApp = false
    var readBattery: () -> BatteryState? = BatteryState.current
    private var batteryStopped = false

    var mode: Mode = .schedule
    var eventSource: CGEventSourceStateID?
    var preventDisplaySleep: Bool
    var wakeOnWindowStart: Bool
    var onStatusChange: (() -> Void)?
    var notices = NoticeCenter()
    var isAccessibilityTrusted: () -> Bool = accessibilityTrusted
    var requestAccessibilityPermission: () -> Void = { requestAccessibility(prompt: true) }

    private(set) var running = false
    private(set) var jiggles = 0
    private(set) var lastJiggle: Date?
    private(set) var lastIdle: Double?
    private var deadline: Date?
    private var windowActive = false
    private var lastCursor: CGPoint?
    private var moveStreak = 0
    private var warnedAboutAccessibility = false
    private var restoreBrightness: Double?
    private var appliedBrightness: Double?
    private var restoreKeyboardLight: Double?
    private var appliedKeyboardLight: Double?
    private var lastTick: Date?
    private var lastUptime: TimeInterval?
    private static let wakeGap: TimeInterval = 5

    init(config: Config) {
        self.config = config
        self.preventDisplaySleep = config.preventDisplaySleep
        self.wakeOnWindowStart = config.wakeDisplayOnWindowStart
        notices.enabled = config.notificationsEnabled
    }

    func start(reason: String) {
        guard !running else { return }
        notices.beginSession()
        waitingForApp = false
        batteryStopped = false
        running = true
        windowActive = false
        lastJiggle = nil
        Log.info("engine: ON (\(reason))")
        onStatusChange?()
    }

    func stop(reason: String) {
        guard running else { return }
        running = false
        power.stopDisplayAssertion()
        windowActive = false
        syncBrightness()
        syncKeyboardLight()
        Log.info("engine: OFF (\(reason))")
        onStatusChange?()
    }

    func toggle() {
        running ? stop(reason: "manual toggle") : start(reason: "manual toggle")
    }

    func setDeadline(_ date: Date?) {
        deadline = date
        if let date {
            Log.info("engine: timer until \(logTimestampFormatter.string(from: date))")
        } else {
            Log.info("engine: timer cleared")
        }
        onStatusChange?()
    }

    func setPreventDisplaySleep(_ value: Bool) {
        preventDisplaySleep = value
        if !value {
            power.stopDisplayAssertion()
            Log.info("display: normal mode (no longer forced on)")
        } else if running && windowActive {
            power.startDisplayAssertion()
        }
        syncBrightness()
        onStatusChange?()
    }

    func setDim(enabled: Bool, brightness level: Double) {
        config.dimWhileActive = enabled
        config.dimBrightness = min(1, max(0, level.isFinite ? level : Config.default.dimBrightness))
        syncBrightness()
        onStatusChange?()
    }

    func apply(config newConfig: Config, respectRuntimeToggles: Bool = true) {
        config = newConfig
        notices.enabled = newConfig.notificationsEnabled
        if !respectRuntimeToggles {
            preventDisplaySleep = newConfig.preventDisplaySleep
            wakeOnWindowStart = newConfig.wakeDisplayOnWindowStart
        }
        if !running { power.stopDisplayAssertion() }
        syncBrightness()
        syncKeyboardLight()
        Log.info("engine: config applied (interval \(Int(config.intervalSeconds[0]))-\(Int(config.intervalSeconds[1]))s, pattern \(config.motionPattern))")
        onStatusChange?()
    }

    @discardableResult
    func jiggleNow() -> Bool {
        guard ensureAccessibility() else { return false }
        let moved = simulateMotion(pattern: config.motionPattern,
                                   distance: config.jiggleDistancePixels,
                                   radius: config.motionRadiusPixels,
                                   stateID: eventSource)
        if moved {
            postExtraActivity()
            jiggles += 1
            lastJiggle = Date()
            lastIdle = userIdleSeconds()
            onStatusChange?()
        }
        return moved
    }

    @discardableResult
    func tick(now: Date = Date()) -> Bool {
        noteWakeIfNeeded(now: now)
        if let deadline, now >= deadline {
            self.deadline = nil
            stop(reason: "timer expired")
            notices.offer(.timerExpired)
            return false
        }
        guard running else { return true }
        if config.batteryLimitEnabled, let battery = readBattery(),
           battery.onBattery, battery.percent <= config.batteryLimitPercent {
            batteryStopped = true
            deadline = nil
            let limit = config.batteryLimitPercent
            stop(reason: "battery at \(battery.percent)% (limit \(limit)%)")
            notices.offer(.batteryStop(percent: battery.percent, limit: limit))
            return false
        }

        let wasWaitingForApp = waitingForApp
        waitingForApp = config.appCondition.enabled && !config.appCondition.allows(readAppActivity())
        let allowed = !waitingForApp && ((mode == .always) || config.schedule.allows(now))
        if allowed != windowActive || wasWaitingForApp != waitingForApp {
            windowActive = allowed
            if allowed {
                Log.info("engine: activity conditions met")
                if preventDisplaySleep { power.startDisplayAssertion() }
                if preventDisplaySleep && wakeOnWindowStart { power.declareUserActivity() }
                lastJiggle = nil
            } else {
                Log.info("engine: waiting for activity conditions, releasing assertion")
                power.stopDisplayAssertion()
            }
            syncBrightness()
            syncKeyboardLight()
            onStatusChange?()
        }

        let cursor = CGEvent(source: nil)?.location
        if let cursor, let previous = lastCursor, cursor != previous {
            moveStreak += 1
            if moveStreak >= 2 { lastJiggle = now }
        } else {
            moveStreak = 0
        }
        lastCursor = cursor

        if windowActive {
            let interval = Double.random(in: config.intervalSeconds[0]...config.intervalSeconds[1])
            let sinceLast = lastJiggle.map { now.timeIntervalSince($0) } ?? .greatestFiniteMagnitude
            let idle = userIdleSeconds()
            lastIdle = idle
            if sinceLast >= interval && idle >= config.idleThresholdSeconds {
                if ensureAccessibility() {
                    if simulateMotion(pattern: config.motionPattern,
                                      distance: config.jiggleDistancePixels,
                                      radius: config.motionRadiusPixels,
                                      stateID: eventSource) {
                        postExtraActivity()
                        jiggles += 1
                        lastJiggle = Date()
                        Log.info(String(format: "%@ #%d (idle %.0fs, wait %.0fs)",
                                        config.motionPattern, jiggles, idle, interval))
                        onStatusChange?()
                    }
                }
            }
        }
        return true
    }

    private func syncBrightness() {
        guard config.dimWhileActive, running, windowActive, preventDisplaySleep else {
            releaseBrightness()
            return
        }
        if restoreBrightness == nil { restoreBrightness = brightness.current() }
        let target = min(1, max(0, config.dimBrightness))
        if let applied = appliedBrightness, abs(applied - target) < 0.005 { return }
        guard brightness.set(target) else {
            appliedBrightness = nil
            restoreBrightness = nil
            Log.error("display: brightness is not controllable on this Mac")
            return
        }
        appliedBrightness = target
        recordOverrides()
        Log.info(String(format: "display: brightness set to %.0f%% while the engine is active", target * 100))
    }

    private func releaseBrightness() {
        guard let original = restoreBrightness else { return }
        let applied = appliedBrightness
        restoreBrightness = nil
        appliedBrightness = nil
        recordOverrides()
        if let applied, let current = brightness.current(), abs(current - applied) > 0.02 {
            Log.info("display: brightness left where it was set by hand")
            return
        }
        guard brightness.set(original) else { return }
        Log.info(String(format: "display: brightness restored to %.0f%%", original * 100))
    }

    private func noteWakeIfNeeded(now: Date) {
        let uptime = readUptime()
        defer {
            lastTick = now
            lastUptime = uptime
        }
        guard let previous = lastTick, let previousUptime = lastUptime else { return }
        guard now.timeIntervalSince(previous) - (uptime - previousUptime) > Self.wakeGap else { return }
        Log.info("system: woke from sleep, re-applying the display and the keyboard light")
        reassert()
    }

    func recoverOverrides() {
        guard let saved = overrides.load(), !saved.isEmpty else { return }
        if let applied = saved.displayApplied, let original = saved.displayOriginal,
           let current = brightness.current(), abs(current - applied) < 0.02 {
            if brightness.set(original) {
                Log.info(String(format: "display: repaired the brightness left by an unclean exit (%.0f%%)",
                                original * 100))
            }
        }
        if let applied = saved.keyboardApplied, let original = saved.keyboardOriginal,
           let current = keyboardLight.current(), abs(current - applied) < 0.02 {
            if keyboardLight.set(original) {
                Log.info(String(format: "keyboard: repaired the backlight left by an unclean exit (%.0f%%)",
                                original * 100))
            }
        }
        overrides.clear()
    }

    private func recordOverrides() {
        let snapshot = Overrides(displayApplied: appliedBrightness,
                                 displayOriginal: restoreBrightness,
                                 keyboardApplied: appliedKeyboardLight,
                                 keyboardOriginal: restoreKeyboardLight)
        if snapshot.isEmpty {
            overrides.clear()
        } else {
            overrides.save(snapshot)
        }
    }

    func reassert() {
        appliedBrightness = nil
        appliedKeyboardLight = nil
        syncBrightness()
        syncKeyboardLight()
    }

    private func syncKeyboardLight() {
        guard config.turnOffKeyboardLight, running, windowActive else {
            releaseKeyboardLight()
            return
        }
        if restoreKeyboardLight == nil { restoreKeyboardLight = keyboardLight.current() }
        if appliedKeyboardLight != nil { return }
        guard keyboardLight.set(0) else {
            appliedKeyboardLight = nil
            restoreKeyboardLight = nil
            Log.error("keyboard: the backlight of this keyboard cannot be turned off")
            return
        }
        appliedKeyboardLight = 0
        recordOverrides()
        Log.info("keyboard: backlight off while the engine is active")
    }

    private func releaseKeyboardLight() {
        guard let original = restoreKeyboardLight else { return }
        let applied = appliedKeyboardLight
        restoreKeyboardLight = nil
        appliedKeyboardLight = nil
        recordOverrides()
        if let applied, let current = keyboardLight.current(), abs(current - applied) > 0.02 {
            Log.info("keyboard: backlight left where it was set by hand")
            return
        }
        guard keyboardLight.set(original) else { return }
        Log.info(String(format: "keyboard: backlight restored to %.0f%%", original * 100))
    }

    private func postExtraActivity() {
        if config.clickMode != "none", clickMouse(config.clickMode, stateID: eventSource) {
            Log.info("activity: click \(config.clickMode) at the current pointer position")
        }
        if config.scrollMode != "none", scrollMouse(config.scrollMode, stateID: eventSource) {
            Log.info("activity: scroll \(config.scrollMode)")
        }
    }

    private func ensureAccessibility() -> Bool {
        if isAccessibilityTrusted() { return true }
        if !warnedAboutAccessibility {
            warnedAboutAccessibility = true
            Log.error("no Accessibility permission: macOS discards cursor events")
            Log.info("System Settings > Privacy & Security > Accessibility")
            notices.offer(.missingAccessibility)
            requestAccessibilityPermission()
        }
        return false
    }

    var status: Status {
        Status(
            batteryStopped: batteryStopped,
            running: running,
            windowActive: windowActive,
            jiggles: jiggles,
            lastJiggle: lastJiggle,
            lastIdle: lastIdle,
            displayAssertion: power.hasDisplayAssertion,
            dimmed: appliedBrightness != nil,
            brightness: brightness.current(),
            keyboardLightOff: appliedKeyboardLight != nil,
            keyboardBrightness: keyboardLight.current(),
            waitingForApp: running && waitingForApp,
            outOfSchedule: running && mode == .schedule && !config.schedule.allows(Date()),
            deadline: deadline,
            nextTransition: config.schedule.nextTransition(after: Date()),
            accessibilityTrusted: isAccessibilityTrusted()
        )
    }

    var shortStatus: String {
        let status = status
        if !status.running { return L("inactive") }
        if status.waitingForApp { return L("Waiting for selected app") }
        if status.outOfSchedule { return L("inactive (out of schedule)") }
        return L("active")
    }

    func statusLine() -> String {
        let status = status
        let deadlineText = status.deadline.map { logTimestampFormatter.string(from: $0) } ?? "-"
        let lastText = status.lastJiggle.map { logTimestampFormatter.string(from: $0) } ?? "-"
        let state: String
        if !status.running { state = "inactive" }
        else if status.waitingForApp { state = "waiting-for-app" }
        else if status.outOfSchedule { state = "out-of-schedule" }
        else { state = "active" }
        return [
            state,
            "jiggles=\(status.jiggles)",
            "display=\(status.displayAssertion ? "kept-awake" : "normal")",
            "brightness=\(status.brightness.map { String(format: "%.2f", $0) } ?? "unknown")",
            "dim=\(status.dimmed ? String(format: "%.2f", config.dimBrightness) : "off")",
            "keyboard=\(status.keyboardLightOff ? "off" : "normal")",
            "last=\(lastText)",
            "timer=\(deadlineText)",
            "accessibility=\(status.accessibilityTrusted ? "ok" : "missing")",
        ].joined(separator: " ")
    }
}
