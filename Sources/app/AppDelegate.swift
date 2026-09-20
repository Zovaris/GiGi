import AppKit
import Carbon.HIToolbox
import ServiceManagement
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let engine: Engine
    private let server = ControlServer()
    private let defaults = UserDefaults.standard
    private var timer: Timer?
    private let panel = PanelModel()
    private let popover = NSPopover()
    private var legacyMenu: NSMenu?
    private var recordingMonitor: Any?

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
        legacyMenu = menu
        configurePanel()
        configureHotkey()
        statusItem.button?.target = self
        statusItem.button?.action = #selector(showPanel)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        if !accessibilityTrusted() && !defaults.bool(forKey: "askedAccessibility") {
            defaults.set(true, forKey: "askedAccessibility")
            Log.info("app: requesting Accessibility permission")
            requestAccessibility(prompt: true)
        }

        let savedDeadline = defaults.object(forKey: "deadline") as? Date
        if let savedDeadline, savedDeadline <= Date() {
            defaults.set(false, forKey: "running")
            defaults.removeObject(forKey: "deadline")
        }
        if defaults.object(forKey: "running") == nil || defaults.bool(forKey: "running") {
            engine.start(reason: "app launch")
            if let savedDeadline, savedDeadline > Date() { engine.setDeadline(savedDeadline) }
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
                self.defaults.set(false, forKey: "running")
            }
            if self.popover.isShown { self.refresh() }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }

        refresh()
        Log.info("app: ready - mode \(engine.mode.rawValue), state \(engine.shortStatus), "
                 + "accessibility \(accessibilityTrusted() ? "ok" : "MISSING")")
    }

    func applicationWillTerminate(_ notification: Notification) {
        engine.stop(reason: "app is quitting")
        stopHotkeyRecording()
        HotkeyCenter.shared.unregister()
        server.stop()
        timer?.invalidate()
        Log.info("app: exiting")
    }

    private func handle(_ request: String) -> String {
        let parts = request.split(separator: " ", maxSplits: 2).map(String.init)
        switch parts.first ?? "status" {
        case "status":
            let hotkey = HotkeyCenter.shared.registered?.config ?? Hotkey.disabledName
            return engine.statusLine() + " hotkey=\(hotkey)"
        case "start":
            startFromPanel()
            defaults.set(true, forKey: "running")
            return "ok: on"
        case "stop":
            engine.stop(reason: "IPC")
            engine.setDeadline(nil)
            defaults.removeObject(forKey: "deadline")
            defaults.set(false, forKey: "running")
            return "ok: off"
        case "toggle":
            toggleEngine()
            return "ok: \(engine.running ? "on" : "off")"
        case "jiggle":
            return engine.jiggleNow() ? "ok: move sent" : "error: missing Accessibility permission"
        case "until":
            guard parts.count > 1, let when = nextOccurrence(ofHM: parts[1], after: Date()) else {
                return "error: invalid time (HH:MM)"
            }
            panel.timerKind = "until"
            panel.until = when
            panel.timerChanged()
            engine.setDeadline(when)
            defaults.set(when, forKey: "deadline")
            return "ok: until \(logTimestampFormatter.string(from: when))"
        case "duration":
            guard parts.count > 1, let minutes = Double(parts[1]), minutes.isFinite,
                  minutes >= 1, minutes <= 10080 else { return "error: invalid minutes (1–10080)" }
            let when = Date().addingTimeInterval(minutes * 60)
            panel.timerKind = "duration"
            panel.minutes = minutes
            panel.timerChanged()
            engine.setDeadline(when)
            defaults.set(when, forKey: "deadline")
            return "ok: until \(logTimestampFormatter.string(from: when))"
        case "reload":
            reloadConfig()
            return "ok: config reloaded (schedule \(engine.config.schedule.enabled ? "ON" : "OFF"))"
        case "panel":
            let destination = parts.count > 1 ? parts[1].lowercased() : ""
            let page = destination == "movement" || destination == "settings" ? destination : nil
            if !popover.isShown { showPanel() }
            panel.drawer = page
            panel.topToken = UUID()
            return page.map { "ok: panel open (\($0))" } ?? "ok: panel open"
        case "menu":
            let lines: [String] = (legacyMenu?.items ?? []).map { item in
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

    private func startFromPanel() {
        guard !engine.running else { return }
        applyPanelTimer()
        engine.start(reason: "panel or IPC")
    }

    @objc private func toggleEngine() {
        if engine.running {
            engine.stop(reason: "panel")
            engine.setDeadline(nil)
            defaults.removeObject(forKey: "deadline")
        } else {
            startFromPanel()
        }
        defaults.set(engine.running, forKey: "running")
    }

    @objc private func moveNow() {
        if engine.jiggleNow() { Log.info("menu: manual move") }
    }

    @objc private func setTimerPreset(_ sender: NSMenuItem) {
        panel.timerKind = sender.tag <= 0 ? "none" : "duration"
        if sender.tag > 0 { panel.minutes = Double(sender.tag) }
        panel.timerChanged()
        refresh()
    }

    @objc private func setUntilTime(_ sender: NSMenuItem) {
        guard let hm = sender.representedObject as? String,
              let when = nextOccurrence(ofHM: hm, after: Date()) else { return }
        panel.timerKind = "until"
        panel.until = when
        panel.timerChanged()
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
        syncPanelFromConfig()
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
        panel.error = nil
        do {
            if service.status == .enabled {
                try service.unregister()
                Log.info("login item: unregistered")
            } else {
                try service.register()
                Log.info("login item: registered")
            }
        } catch {
            panel.error = error.localizedDescription
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
        panel.status = status
        panel.preventDisplaySleep = engine.preventDisplaySleep
        panel.mode = engine.mode.rawValue
        panel.login = SMAppService.mainApp.status == .enabled
        panel.intervalSummary = String(format: L("After %.0fs idle · every %.0f–%.0fs"),
                                       engine.config.idleThresholdSeconds,
                                       engine.config.intervalSeconds[0], engine.config.intervalSeconds[1])

        let indicator = StatusIcon.state(for: status)
        statusItem.button?.image = StatusIcon.image(for: indicator, appearance: statusItem.button?.effectiveAppearance, running: status.running)
        let description = "GiGi: " + L(indicator.label)
        statusItem.button?.toolTip = description + " · " + String(format: L("%d movements"), status.jiggles)
        statusItem.button?.setAccessibilityLabel(description)

        refreshMenu(status)
    }

    private func refreshMenu(_ status: Engine.Status) {
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
        if status.dimmed {
            details.append(String(format: L("dimmed %d%%"), Int((engine.config.dimBrightness * 100).rounded())))
        }
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

private extension AppDelegate {
    private func configurePanel() {
        panel.language = defaults.string(forKey: "appLanguage") ?? "system"
        panel.theme = defaults.string(forKey: "appTheme") ?? "system"
        applyAppearance()
        panel.preferencesChanged = { [weak self] in
            guard let self else { return }
            self.defaults.set(self.panel.language, forKey: "appLanguage")
            self.defaults.set(self.panel.theme, forKey: "appTheme")
            self.applyAppearance()
            if let menu = self.legacyMenu {
                menu.removeAllItems()
                self.buildMenu(menu)
            }
            self.refresh()
        }
        panel.timerKind = defaults.string(forKey: "timerKind") ?? "none"
        panel.minutes = defaults.object(forKey: "timerMinutes") as? Double ?? 60
        panel.until = defaults.object(forKey: "timerUntil") as? Date ?? Date()
        panel.toggle = { [weak self] in self?.toggleEngine() }
        panel.screen = { [weak self] in self?.toggleScreenAssertion() }
        panel.modeChanged = { [weak self] value in
            guard let self else { return }
            self.engine.mode = Engine.Mode(rawValue: value) ?? .schedule
            self.defaults.set(value, forKey: "mode")
            self.refresh()
        }
        panel.timerChanged = { [weak self] in
            guard let self else { return }
            self.panel.minutes = self.panel.minutes.isFinite ? max(1, min(10080, self.panel.minutes)) : 60
            self.defaults.set(self.panel.timerKind, forKey: "timerKind")
            self.defaults.set(self.panel.minutes, forKey: "timerMinutes")
            self.defaults.set(self.panel.until, forKey: "timerUntil")
            if self.engine.running { self.applyPanelTimer() }
        }
        panel.clickMode = engine.config.clickMode
        panel.scrollMode = engine.config.scrollMode
        panel.movementChanged = { [weak self] in self?.applyPanelMovement() }
        panel.dimPreview = { [weak self] in self?.previewPanelDim() }
        panel.dimChanged = { [weak self] in self?.applyPanelDim() }
        panel.recordHotkey = { [weak self] in self?.toggleHotkeyRecording() }
        panel.accessibility = { [weak self] in self?.openAccessibilityPane() }
        panel.move = { [weak self] in self?.moveNow() }
        panel.reload = { [weak self] in self?.reloadConfig() }
        panel.configFolder = { [weak self] in self?.openConfigFolder() }
        panel.log = { [weak self] in self?.openLog() }
        panel.loginChanged = { [weak self] in self?.toggleLaunchAtLogin() }
        panel.heightChanged = { [weak self] in self?.sizePanel() }
        panel.quit = { NSApp.terminate(nil) }
        popover.behavior = .transient
        let controller = NSHostingController(rootView: PanelView(model: panel))
        controller.sizingOptions = []
        popover.contentViewController = controller
        popover.contentSize = NSSize(width: 360, height: panel.panelHeight)
    }

    private func syncPanelFromConfig() {
        panel.idleThreshold = engine.config.idleThresholdSeconds
        panel.intervalLow = engine.config.intervalSeconds[0]
        panel.intervalHigh = engine.config.intervalSeconds[1]
        panel.clickMode = engine.config.clickMode
        panel.scrollMode = engine.config.scrollMode
        panel.dimWhileActive = engine.config.dimWhileActive
        panel.dimBrightness = engine.config.dimBrightness
        panel.hotkey = engine.config.hotkey
        panel.hotkeyDisplay = HotkeyCenter.shared.registered?.display ?? ""
    }

    private func configureHotkey() {
        HotkeyCenter.shared.onPress = { [weak self] in
            guard let self else { return }
            self.toggleEngine()
            Log.info("hotkey: engine is now \(self.engine.running ? "ON" : "OFF")")
        }
        applyHotkey(engine.config.hotkey)
    }

    private func applyHotkey(_ text: String) {
        var config = engine.config
        config.hotkey = text
        panel.hotkey = text
        panel.recordingHotkey = false
        panel.error = nil
        if text == Hotkey.disabledName {
            HotkeyCenter.shared.unregister()
        } else if let hotkey = Hotkey.parse(text) {
            if !HotkeyCenter.shared.register(hotkey) {
                panel.error = String(format: L("Could not register %@"), hotkey.display)
            }
        } else {
            panel.error = L("Unsupported shortcut")
        }
        engine.apply(config: config)
        panel.hotkeyDisplay = HotkeyCenter.shared.registered?.display ?? ""
        if !saveConfig(config, path: AppDelegate.configPathFromArguments()) {
            panel.error = L("Could not write the configuration file")
        }
        refresh()
    }

    private func toggleHotkeyRecording() {
        if panel.recordingHotkey {
            stopHotkeyRecording()
            refresh()
            return
        }
        panel.recordingHotkey = true
        recordingMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            self?.finishHotkeyRecording(with: event)
            return nil
        }
    }

    private func stopHotkeyRecording() {
        if let recordingMonitor { NSEvent.removeMonitor(recordingMonitor) }
        recordingMonitor = nil
        panel.recordingHotkey = false
    }

    private func finishHotkeyRecording(with event: NSEvent) {
        stopHotkeyRecording()
        if event.keyCode == UInt16(kVK_Escape) {
            refresh()
            return
        }
        if event.keyCode == UInt16(kVK_Delete) || event.keyCode == UInt16(kVK_ForwardDelete) {
            applyHotkey(Hotkey.disabledName)
            return
        }
        let modifiers = carbonModifiers(event.modifierFlags)
        guard let hotkey = Hotkey.from(keyCode: UInt32(event.keyCode), modifiers: modifiers) else {
            panel.error = L("Unsupported shortcut")
            refresh()
            return
        }
        if hotkey.modifiers == 0 && !hotkey.config.hasPrefix("f") {
            panel.error = L("Use at least one modifier key")
            refresh()
            return
        }
        applyHotkey(hotkey.config)
    }

    private func carbonModifiers(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        let flags = flags.intersection(.deviceIndependentFlagsMask)
        var modifiers: UInt32 = 0
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        return modifiers
    }

    private func applyAppearance() {
        switch panel.theme {
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        default: NSApp.appearance = nil
        }
    }

    private func applyPanelMovement() {
        var config = engine.config
        config.idleThresholdSeconds = clampSeconds(panel.idleThreshold, fallback: config.idleThresholdSeconds)
        let low = clampSeconds(panel.intervalLow, fallback: config.intervalSeconds[0])
        let high = clampSeconds(panel.intervalHigh, fallback: config.intervalSeconds[1])
        config.intervalSeconds = [min(low, high), max(low, high)]
        config.clickMode = panel.clickMode
        config.scrollMode = panel.scrollMode
        engine.apply(config: config)
        panel.error = saveConfig(config, path: AppDelegate.configPathFromArguments())
            ? nil : L("Could not write the configuration file")
        syncPanelFromConfig()
        refresh()
    }

    private func previewPanelDim() {
        engine.setDim(enabled: panel.dimWhileActive, brightness: panel.dimBrightness)
        panel.dimBrightness = engine.config.dimBrightness
        panel.status = engine.status
    }

    private func applyPanelDim() {
        previewPanelDim()
        panel.error = saveConfig(engine.config, path: AppDelegate.configPathFromArguments())
            ? nil : L("Could not write the configuration file")
        refresh()
    }

    private func clampSeconds(_ value: Double, fallback: Double) -> Double {
        guard value.isFinite else { return fallback }
        return min(3600, max(1, value.rounded()))
    }

    private func applyPanelTimer() {
        let deadline: Date?
        switch panel.timerKind {
        case "duration": deadline = Date().addingTimeInterval(max(1, min(10080, panel.minutes)) * 60)
        case "until":
            let components = Calendar.current.dateComponents([.hour, .minute], from: panel.until)
            deadline = Calendar.current.nextDate(after: Date(), matching: components, matchingPolicy: .nextTime)
        default: deadline = nil
        }
        engine.setDeadline(deadline)
        if let deadline { defaults.set(deadline, forKey: "deadline") }
        else { defaults.removeObject(forKey: "deadline") }
    }

    private func sizePanel() {
        guard let button = statusItem.button, let window = button.window, let screen = window.screen else { return }
        let anchor = window.convertToScreen(button.convert(button.bounds, to: nil))
        let availableHeight = min(anchor.minY, screen.visibleFrame.maxY) - screen.visibleFrame.minY - 32
        panel.maxHeight = max(240, availableHeight)
        let size = NSSize(width: 360, height: panel.panelHeight)
        guard popover.contentSize != size else { return }
        popover.contentViewController?.preferredContentSize = size
        popover.contentViewController?.view.setFrameSize(size)
        popover.contentSize = size
    }

    @objc private func showPanel() {
        guard let button = statusItem.button else { return }
        if NSApp.currentEvent?.type == .rightMouseUp, let menu = legacyMenu {
            refresh()
            rebuildRecentMenu()
            statusItem.menu = menu
            button.performClick(nil)
            statusItem.menu = nil
            return
        }
        if popover.isShown { popover.performClose(nil) }
        else {
            refresh()
            syncPanelFromConfig()
            panel.drawer = nil
            panel.topToken = UUID()
            sizePanel()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
            DispatchQueue.main.async { self.popover.contentViewController?.view.window?.makeFirstResponder(nil) }
        }
    }

}
