import Foundation
import CoreGraphics

final class Engine {
    enum Mode: String {
        case schedule
        case always
    }

    struct Status {
        var running: Bool = false
        var windowActive: Bool = false
        var jiggles: Int = 0
        var lastJiggle: Date?
        var lastIdle: Double?
        var displayAssertion: Bool = false
        var outOfSchedule: Bool = false
        var deadline: Date?
        var nextTransition: Date?
        var accessibilityTrusted: Bool = false
    }

    private(set) var config: Config
    private let power = PowerAssertions()

    var mode: Mode = .schedule
    var eventSource: CGEventSourceStateID?
    var preventDisplaySleep: Bool
    var wakeOnWindowStart: Bool
    var onStatusChange: (() -> Void)?

    private(set) var running = false
    private(set) var jiggles = 0
    private(set) var lastJiggle: Date?
    private(set) var lastIdle: Double?
    private var deadline: Date?
    private var windowActive = false
    private var lastCursor: CGPoint?
    private var moveStreak = 0
    private var warnedAboutAccessibility = false

    init(config: Config) {
        self.config = config
        self.preventDisplaySleep = config.preventDisplaySleep
        self.wakeOnWindowStart = config.wakeDisplayOnWindowStart
    }

    func start(reason: String) {
        guard !running else { return }
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
        onStatusChange?()
    }

    func apply(config newConfig: Config, respectRuntimeToggles: Bool = true) {
        config = newConfig
        if !respectRuntimeToggles {
            preventDisplaySleep = newConfig.preventDisplaySleep
            wakeOnWindowStart = newConfig.wakeDisplayOnWindowStart
        }
        if !running { power.stopDisplayAssertion() }
        Log.info("engine: config applied (interval \(Int(config.intervalSeconds[0]))-\(Int(config.intervalSeconds[1]))s)")
        onStatusChange?()
    }

    @discardableResult
    func jiggleNow() -> Bool {
        guard ensureAccessibility() else { return false }
        let moved = jiggle(distance: config.jiggleDistancePixels, stateID: eventSource)
        if moved {
            jiggles += 1
            lastJiggle = Date()
            lastIdle = userIdleSeconds()
            onStatusChange?()
        }
        return moved
    }

    @discardableResult
    func tick(now: Date = Date()) -> Bool {
        if let deadline, now >= deadline {
            self.deadline = nil
            stop(reason: "timer expired")
            return false
        }
        guard running else { return true }

        let allowed = (mode == .always) || config.schedule.allows(now)
        if allowed != windowActive {
            windowActive = allowed
            if allowed {
                Log.info("engine: entering active schedule window")
                if preventDisplaySleep { power.startDisplayAssertion() }
                if preventDisplaySleep && wakeOnWindowStart { power.declareUserActivity() }
                lastJiggle = nil
            } else {
                Log.info("engine: outside schedule window, releasing assertion")
                power.stopDisplayAssertion()
            }
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
                    if jiggle(distance: config.jiggleDistancePixels, stateID: eventSource) {
                        jiggles += 1
                        lastJiggle = Date()
                        Log.info(String(format: "jiggle #%d (idle %.0fs, wait %.0fs)", jiggles, idle, interval))
                        onStatusChange?()
                    }
                }
            }
        }
        return true
    }

    private func ensureAccessibility() -> Bool {
        if accessibilityTrusted() { return true }
        if !warnedAboutAccessibility {
            warnedAboutAccessibility = true
            Log.error("no Accessibility permission: macOS discards cursor events")
            Log.info("System Settings > Privacy & Security > Accessibility")
            requestAccessibility(prompt: true)
        }
        return false
    }

    var status: Status {
        Status(
            running: running,
            windowActive: windowActive,
            jiggles: jiggles,
            lastJiggle: lastJiggle,
            lastIdle: lastIdle,
            displayAssertion: power.hasDisplayAssertion,
            outOfSchedule: running && mode == .schedule && !config.schedule.allows(Date()),
            deadline: deadline,
            nextTransition: config.schedule.nextTransition(after: Date()),
            accessibilityTrusted: accessibilityTrusted()
        )
    }

    var shortStatus: String {
        let status = status
        if !status.running { return L("inactive") }
        if status.outOfSchedule { return L("inactive (out of schedule)") }
        return L("active")
    }

    func statusLine() -> String {
        let status = status
        let deadlineText = status.deadline.map { logTimestampFormatter.string(from: $0) } ?? "-"
        let lastText = status.lastJiggle.map { logTimestampFormatter.string(from: $0) } ?? "-"
        return [
            status.running ? (status.outOfSchedule ? "out-of-schedule" : "active") : "inactive",
            "jiggles=\(status.jiggles)",
            "display=\(status.displayAssertion ? "kept-awake" : "normal")",
            "last=\(lastText)",
            "timer=\(deadlineText)",
            "accessibility=\(status.accessibilityTrusted ? "ok" : "missing")",
        ].joined(separator: " ")
    }
}
