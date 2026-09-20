import Foundation
import CoreGraphics
import ApplicationServices

func usage() {
    print("""
    gigi - keeps the display awake and simulates user activity on macOS

    LOCAL ENGINE:
      gigi run     [options]    blocking loop (daemon / LaunchAgent)
      gigi once    [options]    a single move, then exit
      gigi probe   [options]    diagnostics; --test measures the idle reset

    MENU BAR APP CONTROL (when the app is running):
      gigi status | start | stop | toggle | jiggle
      gigi until HH:MM | duration MIN | reload | menu | panel | quit-app

    OPTIONS:
      --config PATH           config JSON (default ~/.config/gigi/config.json)
      --interval-min S        minimum seconds between moves (default 45)
      --interval-max S        maximum seconds between moves (default 90)
      --distance PX           cursor offset in pixels (default 2)
      --idle-threshold S      only move when the user has been idle for S seconds (default 40)
      --until HH:MM           stop at that time (today, or tomorrow if already past)
      --duration MIN          stop after N minutes
      --no-assert             do not create the display assertion
      --ignore-schedule       ignore the schedule in the config
      --source nil|private    CGEvent source (default nil)
      --test                  (probe) run the idle reset test
      --wait-idle S           (probe --test) wait until S seconds idle (default 8)
      --quiet                 less output
      --force                 start the daemon even if the app is running
    """)
}

struct Options {
    var command = "run"
    var configPath: String?
    var intervalMin: Double?
    var intervalMax: Double?
    var distance: Double?
    var idleThreshold: Double?
    var until: String?
    var durationMinutes: Double?
    var noAssert = false
    var ignoreSchedule = false
    var source: CGEventSourceStateID?
    var test = false
    var waitIdle: Double = 8
    var quiet = false
    var force = false
    var extra: [String] = []
}

func parseOptions(_ args: [String]) -> Options {
    var options = Options()
    var index = 0
    if let first = args.first, !first.hasPrefix("-") {
        options.command = first
        index = 1
    }
    func nextValue(_ name: String) -> String? {
        guard index + 1 < args.count else {
            Log.info("missing value for \(name)")
            return nil
        }
        index += 1
        return args[index]
    }
    while index < args.count {
        switch args[index] {
        case "--config":
            options.configPath = nextValue("--config")
        case "--interval-min":
            options.intervalMin = nextValue("--interval-min").flatMap(Double.init)
        case "--interval-max":
            options.intervalMax = nextValue("--interval-max").flatMap(Double.init)
        case "--distance":
            options.distance = nextValue("--distance").flatMap(Double.init)
        case "--idle-threshold":
            options.idleThreshold = nextValue("--idle-threshold").flatMap(Double.init)
        case "--until":
            options.until = nextValue("--until")
        case "--duration":
            options.durationMinutes = nextValue("--duration").flatMap(Double.init)
        case "--no-assert":
            options.noAssert = true
        case "--ignore-schedule":
            options.ignoreSchedule = true
        case "--source":
            if let value = nextValue("--source") {
                options.source = (value == "private") ? .privateState : nil
            }
        case "--test":
            options.test = true
        case "--wait-idle":
            options.waitIdle = nextValue("--wait-idle").flatMap(Double.init) ?? 8
        case "--quiet":
            options.quiet = true
        case "--force":
            options.force = true
        case "-h", "--help", "help":
            options.command = "help"
        default:
            if args[index].hasPrefix("-") {
                Log.info("unknown option: \(args[index])")
                options.command = "help"
            } else {
                options.extra.append(args[index])
            }
        }
        index += 1
    }
    return options
}

func makeEngine(_ options: Options) -> Engine {
    var config = loadConfig(path: options.configPath)
    if let value = options.intervalMin { config.intervalSeconds[0] = value }
    if let value = options.intervalMax { config.intervalSeconds[1] = value }
    if let value = options.distance { config.jiggleDistancePixels = value }
    if let value = options.idleThreshold { config.idleThresholdSeconds = value }
    if options.noAssert { config.preventDisplaySleep = false }
    let engine = Engine(config: config)
    if options.ignoreSchedule { engine.mode = .always }
    engine.eventSource = options.source
    return engine
}

func runProbe(_ options: Options) {
    let appStatus = ControlIPC.send("status")
    print("""
    === environment ===
    macOS:            \(ProcessInfo.processInfo.operatingSystemVersionString)
    binary:           \(CommandLine.arguments[0])
    accessibility:    \(accessibilityTrusted() ? "GRANTED" : "NOT granted (the cursor will not move)")
    idle (HID):       \(String(format: "%.1f", userIdleSeconds())) s (CGEventSource .hidSystemState)
    idle (kernel):    \(hidIdleSeconds().map { String(format: "%.1f s (ioreg HIDIdleTime)", $0) } ?? "n/a")
    menu bar app:     \(appStatus.map { "running -> \($0)" } ?? "not running")
    """)

    guard options.test else { return }

    let horizon = Date().addingTimeInterval(90)
    while userIdleSeconds() < options.waitIdle && Date() < horizon {
        print("waiting for idle (\(String(format: "%.1f", userIdleSeconds()))s / \(options.waitIdle)s) - do not touch keyboard or trackpad")
        Thread.sleep(forTimeInterval: 2)
    }

    let before = userIdleSeconds()
    let beforeKernel = hidIdleSeconds()
    print(String(format: "\n=== reset test ===\nidle before: %.1f s (kernel: %@)",
                 before, beforeKernel.map { String(format: "%.1f s", $0) } ?? "n/a"))

    let distance = options.distance ?? Config.default.jiggleDistancePixels
    let sourceName = options.source == .privateState ? "privateState" : "nil (system)"
    Log.info("posting mouseMoved (+\(distance)px and back) with source=\(sourceName)")
    guard jiggle(distance: distance, stateID: options.source) else { return }
    Thread.sleep(forTimeInterval: 0.4)

    let after = userIdleSeconds()
    let afterKernel = hidIdleSeconds()
    print(String(format: "idle after:  %.1f s (kernel: %@)",
                 after, afterKernel.map { String(format: "%.1f s", $0) } ?? "n/a"))
    print("result: \(after < 1.5 ? "IDLE TIMER RESET OK" : "IDLE TIMER NOT RESET")")
}

func runOnce(_ options: Options) {
    let engine = makeEngine(options)
    guard engine.jiggleNow() else {
        Log.error("could not move the cursor (Accessibility permission?)")
        exit(1)
    }
    Log.info("single move of \(engine.config.jiggleDistancePixels)px sent")
}

var stopRequested = false

func installSignalHandlers() {
    signal(SIGINT) { _ in stopRequested = true }
    signal(SIGTERM) { _ in stopRequested = true }
}

func runLoop(_ options: Options) {
    if !options.force, let reply = ControlIPC.send("status") {
        Log.info("the menu bar app is already running -> \(reply)")
        Log.info("not starting the daemon to avoid duplicating; quit the app or use --force")
        return
    }

    let engine = makeEngine(options)
    let config = engine.config

    var deadline: Date?
    if let until = options.until {
        guard let when = nextOccurrence(ofHM: until, after: Date()) else {
            Log.error("--until is invalid, expected HH:MM")
            exit(2)
        }
        deadline = when
    }
    if let minutes = options.durationMinutes {
        let when = Date().addingTimeInterval(minutes * 60)
        deadline = deadline.map { min($0, when) } ?? when
    }

    if !accessibilityTrusted() {
        Log.error("no Accessibility permission: the display stays awake but the cursor will not move")
        Log.info("System Settings > Privacy & Security > Accessibility")
        requestAccessibility(prompt: true)
    }

    Log.info("starting daemon: interval \(Int(config.intervalSeconds[0]))-\(Int(config.intervalSeconds[1]))s, "
             + "distance \(config.jiggleDistancePixels)px, idle>\(Int(config.idleThresholdSeconds))s, "
             + "schedule \(engine.mode == .always ? "ignored" : (config.schedule.enabled ? "ON" : "OFF"))")
    engine.setDeadline(deadline)
    engine.start(reason: "CLI run")

    installSignalHandlers()
    while !stopRequested {
        engine.tick()
        Thread.sleep(forTimeInterval: 1)
    }
    engine.stop(reason: "signal received")
    Log.info("stopped cleanly")
}

func forwardToApp(_ request: String, hint: String) {
    if let reply = ControlIPC.send(request) {
        print(reply)
    } else {
        print("the menu bar app is not running.")
        print(hint)
        exit(1)
    }
}

let options = parseOptions(Array(CommandLine.arguments.dropFirst()))
switch options.command {
case "help":
    usage()

case "probe":
    runProbe(options)

case "once":
    runOnce(options)

case "run", "start-daemon":
    runLoop(options)

case "status":
    if let reply = ControlIPC.send("status") {
        print(reply)
    } else {
        print("menu bar app: not running")
        print("current idle: \(String(format: "%.1f", userIdleSeconds())) s, "
              + "accessibility: \(accessibilityTrusted() ? "ok" : "missing")")
        print("hint: open the app (open app/GiGi.app) or run 'gigi run' as a daemon")
    }

case "start", "stop", "toggle", "jiggle":
    forwardToApp(options.command, hint: "hint: open app/GiGi.app")

case "until":
    guard let hm = options.extra.first else {
        print("usage: gigi until HH:MM")
        exit(2)
    }
    forwardToApp("until \(hm)", hint: "hint: open app/GiGi.app")

case "duration":
    guard let minutes = options.extra.first else {
        print("usage: gigi duration MINUTES")
        exit(2)
    }
    forwardToApp("duration \(minutes)", hint: "hint: open app/GiGi.app")

case "reload":
    forwardToApp("reload", hint: "hint: open app/GiGi.app")

case "menu":
    forwardToApp("menu", hint: "hint: open app/GiGi.app")

case "panel":
    forwardToApp("panel", hint: "hint: open app/GiGi.app")

case "quit-app":
    forwardToApp("quit", hint: "the app was already closed")

default:
    usage()
}
