import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let engine: Engine
    private let server = ControlServer()
    private let defaults = UserDefaults.standard
    private var timer: Timer?

    private var statusTitleItem: NSMenuItem!
    private var statusDetailItem: NSMenuItem!
    private var toggleItem: NSMenuItem!
    private var jiggleItem: NSMenuItem!
    private var timerMenuItem: NSMenuItem!
    private var modeMenuItem: NSMenuItem!
    private var screenItem: NSMenuItem!
    private var accessibilityItem: NSMenuItem!
    private var launchAtLoginItem: NSMenuItem!
    private var recentMenuItem: NSMenuItem!

    override init() {
        let configPath = AppDelegate.configPathFromArguments()
        engine = Engine(config: loadConfig(path: configPath))
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        NSApp.setActivationPolicy(.accessory)
        if let configPath { defaults.set(configPath, forKey: "configPath") }
    }

    private static func configPathFromArguments() -> String? {
        let args = CommandLine.arguments
        if let index = args.firstIndex(of: "--config"), index + 1 < args.count {
            return args[index + 1]
        }
        return UserDefaults.standard.string(forKey: "configPath")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        engine.mode = Engine.Mode(rawValue: defaults.string(forKey: "mode") ?? "") ?? .schedule
        if defaults.object(forKey: "preventDisplaySleep") != nil {
            engine.preventDisplaySleep = defaults.bool(forKey: "preventDisplaySleep")
        }
        engine.onStatusChange = { [weak self] in self?.refresh() }

        let menu = NSMenu()
        buildMenu(menu)
        menu.delegate = self
        statusItem.menu = menu

        if !accessibilityTrusted() && !defaults.bool(forKey: "askedAccessibility") {
            defaults.set(true, forKey: "askedAccessibility")
            Log.info("app: requesting Accessibility permission")
            requestAccessibility(prompt: true)
        }

        if defaults.object(forKey: "running") == nil || defaults.bool(forKey: "running") {
            engine.start(reason: "app launch")
        }
        if let deadline = defaults.object(forKey: "deadline") as? Date, deadline > Date() {
            engine.setDeadline(deadline)
        }

        if server.start() {
            server.handler = { [weak self] request in
                self?.handle(request) ?? "error: app unavailable"
            }
        }

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            if !self.engine.tick() {
                self.defaults.removeObject(forKey: "deadline")
            }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }

        refresh()
        Log.info("app: ready - mode \(engine.mode.rawValue), state \(engine.shortStatus), "
                 + "accessibility \(accessibilityTrusted() ? "ok" : "MISSING")")
    }

    func applicationWillTerminate(_ notification: Notification) {
        engine.stop(reason: "app is quitting")
        server.stop()
        timer?.invalidate()
        Log.info("app: exiting")
    }

    private func handle(_ request: String) -> String {
        let parts = request.split(separator: " ", maxSplits: 2).map(String.init)
        switch parts.first ?? "status" {
        case "status":
            return engine.statusLine()
        case "start":
            engine.start(reason: "IPC")
            defaults.set(true, forKey: "running")
            return "ok: on"
        case "stop":
            engine.stop(reason: "IPC")
            defaults.set(false, forKey: "running")
            return "ok: off"
        case "toggle":
            engine.toggle()
            defaults.set(engine.running, forKey: "running")
            return "ok: \(engine.running ? "on" : "off")"
        case "jiggle":
            return engine.jiggleNow() ? "ok: move sent" : "error: missing Accessibility permission"
        case "until":
            guard parts.count > 1, let when = nextOccurrence(ofHM: parts[1], after: Date()) else {
                return "error: invalid time (HH:MM)"
            }
            engine.setDeadline(when)
            defaults.set(when, forKey: "deadline")
            return "ok: until \(logTimestampFormatter.string(from: when))"
        case "duration":
            guard parts.count > 1, let minutes = Double(parts[1]) else { return "error: invalid minutes" }
            let when = Date().addingTimeInterval(minutes * 60)
            engine.setDeadline(when)
            defaults.set(when, forKey: "deadline")
            return "ok: until \(logTimestampFormatter.string(from: when))"
        case "reload":
            reloadConfig()
            return "ok: config reloaded (schedule \(engine.config.schedule.enabled ? "ON" : "OFF"))"
        case "menu":
            let lines: [String] = (statusItem.menu?.items ?? []).map { item in
                let mark = item.state == .on ? "[x] " : (item.action != nil ? "[ ] " : "    ")
                guard let submenu = item.submenu else { return mark + item.title }
                let sub = submenu.items
                    .map { ($0.state == .on ? "[x] " : "[ ] ") + $0.title }
                    .joined(separator: " | ")
                return mark + item.title + ": " + sub
            }
            return lines.joined(separator: "\n")
        case "quit":
            DispatchQueue.main.async { NSApp.terminate(nil) }
            return "ok: quitting"
        default:
            return "error: unknown command '\(parts.first ?? "")'"
        }
    }

    @objc private func toggleEngine() {
        engine.toggle()
        defaults.set(engine.running, forKey: "running")
    }

    @objc private func moveNow() {
        if engine.jiggleNow() { Log.info("menu: manual move") }
    }

    @objc private func setTimerPreset(_ sender: NSMenuItem) {
        let minutes = sender.tag
        if minutes <= 0 {
            engine.setDeadline(nil)
            defaults.removeObject(forKey: "deadline")
        } else {
            let when = Date().addingTimeInterval(Double(minutes) * 60)
            engine.setDeadline(when)
            defaults.set(when, forKey: "deadline")
        }
        refresh()
    }

    @objc private func setUntilTime(_ sender: NSMenuItem) {
        guard let hm = sender.representedObject as? String,
              let when = nextOccurrence(ofHM: hm, after: Date()) else { return }
        engine.setDeadline(when)
        defaults.set(when, forKey: "deadline")
        refresh()
    }

    @objc private func setMode(_ sender: NSMenuItem) {
        engine.mode = Engine.Mode(rawValue: sender.representedObject as? String ?? "schedule") ?? .schedule
        defaults.set(engine.mode.rawValue, forKey: "mode")
        Log.info("menu: mode \(engine.mode.rawValue)")
        refresh()
    }

    @objc private func toggleScreenAssertion() {
        engine.setPreventDisplaySleep(!engine.preventDisplaySleep)
        defaults.set(engine.preventDisplaySleep, forKey: "preventDisplaySleep")
    }

    @objc private func reloadConfig() {
        engine.apply(config: loadConfig(path: AppDelegate.configPathFromArguments()))
        refresh()
    }

    @objc private func openAccessibilityPane() {
        Log.info("menu: opening Accessibility pane")
        requestAccessibility(prompt: true)
        openAccessibilitySettings()
    }

    @objc private func openConfigFolder() {
        let url = defaultConfigURL().deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }

    @objc private func openLog() {
        if let fileURL = Log.fileURL { NSWorkspace.shared.open(fileURL) }
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
                Log.info("login item: unregistered")
            } else {
                try service.register()
                Log.info("login item: registered")
            }
        } catch {
            Log.error("login item: \(error.localizedDescription) (is the app in /Applications?)")
        }
        refresh()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func buildMenu(_ menu: NSMenu) {
        menu.autoenablesItems = false

        statusTitleItem = NSMenuItem(title: L("State"), action: nil, keyEquivalent: "")
        statusTitleItem.isEnabled = false
        menu.addItem(statusTitleItem)

        statusDetailItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        statusDetailItem.isEnabled = false
        menu.addItem(statusDetailItem)

        menu.addItem(.separator())

        toggleItem = NSMenuItem(title: L("Turn on"), action: #selector(toggleEngine), keyEquivalent: "t")
        toggleItem.target = self
        menu.addItem(toggleItem)

        jiggleItem = NSMenuItem(title: L("Move now"), action: #selector(moveNow), keyEquivalent: "j")
        jiggleItem.target = self
        menu.addItem(jiggleItem)

        timerMenuItem = NSMenuItem(title: L("Timer"), action: nil, keyEquivalent: "")
        let timerMenu = NSMenu()
        timerMenu.autoenablesItems = false
        let presets: [(String, Int)] = [
            ("No limit", 0), ("15 minutes", 15), ("1 hour", 60), ("4 hours", 240), ("9 hours", 540),
        ]
        for (key, minutes) in presets {
            let item = NSMenuItem(title: L(key), action: #selector(setTimerPreset(_:)), keyEquivalent: "")
            item.target = self
            item.tag = minutes
            timerMenu.addItem(item)
        }
        timerMenu.addItem(.separator())
        for hm in ["18:00", "22:00", "06:00"] {
            let item = NSMenuItem(title: String(format: L("Until %@"), hm),
                                  action: #selector(setUntilTime(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = hm
            timerMenu.addItem(item)
        }
        timerMenuItem.submenu = timerMenu
        menu.addItem(timerMenuItem)

        modeMenuItem = NSMenuItem(title: L("Mode"), action: nil, keyEquivalent: "")
        let modeMenu = NSMenu()
        modeMenu.autoenablesItems = false
        let modes: [(String, String)] = [
            ("Respect config schedule", "schedule"), ("Always force", "always"),
        ]
        for (key, value) in modes {
            let item = NSMenuItem(title: L(key), action: #selector(setMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = value
            modeMenu.addItem(item)
        }
        modeMenuItem.submenu = modeMenu
        menu.addItem(modeMenuItem)

        screenItem = NSMenuItem(title: L("Keep display awake"),
                                action: #selector(toggleScreenAssertion), keyEquivalent: "")
        screenItem.target = self
        menu.addItem(screenItem)

        menu.addItem(.separator())

        recentMenuItem = NSMenuItem(title: L("Recent activity"), action: nil, keyEquivalent: "")
        recentMenuItem.submenu = NSMenu()
        menu.addItem(recentMenuItem)

        accessibilityItem = NSMenuItem(title: L("Accessibility permission…"),
                                       action: #selector(openAccessibilityPane), keyEquivalent: "")
        accessibilityItem.target = self
        menu.addItem(accessibilityItem)

        let reloadItem = NSMenuItem(title: L("Reload config"), action: #selector(reloadConfig), keyEquivalent: "r")
        reloadItem.target = self
        menu.addItem(reloadItem)

        let folderItem = NSMenuItem(title: L("Open config folder"),
                                    action: #selector(openConfigFolder), keyEquivalent: "")
        folderItem.target = self
        menu.addItem(folderItem)

        let logItem = NSMenuItem(title: L("Open log"), action: #selector(openLog), keyEquivalent: "l")
        logItem.target = self
        menu.addItem(logItem)

        launchAtLoginItem = NSMenuItem(title: L("Start at login"),
                                       action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: L("Quit"), action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        refresh()
        rebuildRecentMenu()
    }

    private func refresh() {
        let status = engine.status

        let symbol: String
        if !status.running {
            symbol = "cursorarrow"
        } else if status.outOfSchedule {
            symbol = "moon.zzz"
        } else {
            symbol = "cursorarrow.motionlines"
        }
        if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "GiGi") {
            image.isTemplate = true
            statusItem.button?.image = image
            statusItem.button?.toolTip = "GiGi: \(engine.shortStatus) · \(status.jiggles)"
        }

        guard statusTitleItem != nil else { return }

        if !status.running {
            statusTitleItem.title = L("Inactive")
        } else if status.outOfSchedule {
            let next = status.nextTransition.map { logTimestampFormatter.string(from: $0) } ?? "-"
            statusTitleItem.title = String(format: L("Inactive (out of schedule) · back %@"), next)
        } else {
            statusTitleItem.title = String(format: L("Active · %d movements"), status.jiggles)
        }

        var details: [String] = [status.displayAssertion ? L("screen on") : L("screen normal")]
        if let idle = status.lastIdle {
            details.append(String(format: L("idle %.0fs"), idle))
        }
        if let deadline = status.deadline {
            details.append(String(format: L("until %@"), logTimestampFormatter.string(from: deadline)))
        }
        statusDetailItem.title = details.joined(separator: " · ")

        toggleItem.title = status.running ? L("Turn off") : L("Turn on")
        jiggleItem.isEnabled = status.accessibilityTrusted

        let timerItems = timerMenuItem.submenu?.items ?? []
        timerItems.forEach { $0.state = .off }
        if let deadline = status.deadline {
            let remaining = deadline.timeIntervalSinceNow / 60
            if let match = timerItems.first(where: { $0.tag > 0 && abs(Double($0.tag) - remaining) <= 2 }) {
                match.state = .on
            }
        } else if let unlimited = timerItems.first(where: { $0.tag == 0 }) {
            unlimited.state = .on
        }

        modeMenuItem.submenu?.items.forEach {
            $0.state = (($0.representedObject as? String) == engine.mode.rawValue) ? .on : .off
        }
        screenItem.state = engine.preventDisplaySleep ? .on : .off

        if status.accessibilityTrusted {
            accessibilityItem.title = L("Accessibility permission: granted")
            accessibilityItem.action = nil
            accessibilityItem.isEnabled = false
        } else {
            accessibilityItem.title = L("Missing Accessibility permission…")
            accessibilityItem.action = #selector(openAccessibilityPane)
            accessibilityItem.isEnabled = true
        }

        launchAtLoginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
    }

    private func rebuildRecentMenu() {
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        let lines = Log.recentText(8)
        if lines.isEmpty {
            let item = NSMenuItem(title: L("no events yet"), action: nil, keyEquivalent: "")
            item.isEnabled = false
            submenu.addItem(item)
        } else {
            for line in lines.reversed() {
                let item = NSMenuItem(title: line, action: nil, keyEquivalent: "")
                item.isEnabled = false
                submenu.addItem(item)
            }
        }
        recentMenuItem.submenu = submenu
    }
}
