import SwiftUI

private let panelAppIcon: NSImage = {
    if let url = Bundle.main.url(forResource: "GiGi", withExtension: "icns"),
       let icon = NSImage(contentsOf: url) {
        return icon
    }
    return NSImage(named: NSImage.applicationIconName) ?? NSImage()
}()

private struct HeaderHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 68
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct FooterHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 50
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

final class PanelModel: ObservableObject {
    @Published var status = Engine.Status()
    @Published private var headerHeight: CGFloat = 68
    @Published private var footerHeight: CGFloat = 50
    @Published private var contentHeight: CGFloat = 0
    @Published var maxHeight: CGFloat = 520

    var panelHeight: CGFloat {
        min(maxHeight, headerHeight + footerHeight + 2 + max(contentHeight, 320))
    }

    private func adjust(_ value: CGFloat, _ stored: CGFloat) -> Bool {
        abs(value - stored) > 0.5
    }

    func setMetrics(header: CGFloat? = nil, footer: CGFloat? = nil, content: CGFloat? = nil) {
        var changed = false
        if let header, adjust(header, headerHeight) { headerHeight = header; changed = true }
        if let footer, adjust(footer, footerHeight) { footerHeight = footer; changed = true }
        if let content, adjust(content, contentHeight) { contentHeight = content; changed = true }
        if changed { heightChanged() }
    }

    var heightChanged: () -> Void = {}
    @Published var preventDisplaySleep = true
    @Published var mode = "schedule"
    @Published var timerKind = "none"
    @Published var minutes: Double = 15
    @Published var until = Date()
    @Published var login = false
    @Published var language = "system"
    @Published var theme = "system"
    var preferencesChanged: () -> Void = {}
    @Published var idleThreshold: Double = 40
    @Published var intervalLow: Double = 45
    @Published var intervalHigh: Double = 90
    @Published var motionPattern = Motion.defaultPattern
    @Published var motionRadius = Motion.defaultRadiusPixels
    @Published var clickMode = "none"
    @Published var scrollMode = "none"
    @Published var dimWhileActive = false
    @Published var dimBrightness: Double = 0.35
    @Published var batteryLimitEnabled = false
    @Published var batteryLimitPercent = 20
    var batteryChanged: () -> Void = {}
    @Published var notificationsEnabled = true
    @Published var notificationsDenied = false
    var notificationsChanged: () -> Void = {}
    @Published var appCondition = AppCondition()
    var appConditionChanged: () -> Void = {}
    var addApp: () -> Void = {}
    @Published var scheduleEnabled = false
    @Published var scheduleStart = Date()
    @Published var scheduleEnd = Date()
    @Published var scheduleDays: Set<String> = []
    @Published var scheduleWindows = 1
    @Published var hotkey: String = Hotkey.default.config
    @Published var hotkeyDisplay: String = Hotkey.default.display
    @Published var recordingHotkey = false
    @Published var intervalSummary = ""
    @Published var drawer: String?
    @Published var topToken = UUID()
    @Published var error: String?

    var brightnessSupported: Bool { status.brightness != nil }

    var toggle: () -> Void = {}
    var screen: () -> Void = {}
    var modeChanged: (String) -> Void = { _ in }
    var timerChanged: () -> Void = {}
    var movementChanged: () -> Void = {}
    var dimPreview: () -> Void = {}
    var dimChanged: () -> Void = {}
    var scheduleChanged: () -> Void = {}
    var recordHotkey: () -> Void = {}
    var accessibility: () -> Void = {}
    var move: () -> Void = {}
    var reload: () -> Void = {}
    var configFolder: () -> Void = {}
    var log: () -> Void = {}
    var loginChanged: () -> Void = {}
    var quit: () -> Void = {}
}

struct PanelView: View {
    @ObservedObject var model: PanelModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var deadlineText: String? {
        guard let deadline = model.status.deadline else { return nil }
        return deadline.formatted(date: .omitted, time: .shortened)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.45)
            ZStack(alignment: .top) {
                mainList
                    .offset(x: model.drawer == nil ? 0 : -360)
                    .allowsHitTesting(model.drawer == nil)
                    .accessibilityHidden(model.drawer != nil)
                if let drawer = model.drawer {
                    drawerPage(drawer)
                        .transition(.move(edge: .trailing))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .clipped()
            .animation(.spring(response: 0.32, dampingFraction: 0.88), value: model.drawer)
            Divider().opacity(0.45)
            footer
        }
        .frame(width: 360, height: model.panelHeight)
        .background(.regularMaterial)
        .preferredColorScheme(model.theme == "dark" ? .dark : model.theme == "light" ? .light : nil)
        .environment(\.locale, model.language == "system" ? .autoupdatingCurrent : Locale(identifier: model.language))
        .onPreferenceChange(HeaderHeightKey.self) { height in
            DispatchQueue.main.async { model.setMetrics(header: height) }
        }
        .onPreferenceChange(FooterHeightKey.self) { height in
            DispatchQueue.main.async { model.setMetrics(footer: height) }
        }
        .onPreferenceChange(ContentHeightKey.self) { height in
            DispatchQueue.main.async { model.setMetrics(content: height) }
        }
    }

    private var header: some View {
        HStack(spacing: 11) {
            Image(nsImage: panelAppIcon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 42, height: 42)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("GiGi").font(.headline)
                Text(statusLabel).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: Binding(get: { model.status.running }, set: { _ in model.toggle() }))
                .labelsHidden()
                .toggleStyle(.switch)
                .accessibilityLabel(L("GiGi active"))
                .pointerCursor()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(GeometryReader { proxy in
            Color.clear.preference(key: HeaderHeightKey.self, value: proxy.size.height)
        })
    }

    private var statusLabel: String {
        if model.status.batteryStopped { return L("Stopped at battery limit") }
        if !model.status.accessibilityTrusted {
            return model.status.displayAssertion ? L("Screen awake · permission pending") : L("Accessibility permission needed")
        }
        if model.status.waitingForApp { return L("Waiting for selected app") }
        if model.status.running && model.status.outOfSchedule { return L("Waiting for schedule") }
        return model.status.running ? L("Active") : L("Inactive")
    }

    private var mainList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    scheduleCard
                    appConditionCard
                    drawerCard
                    if let error = model.error {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !model.status.accessibilityTrusted { permissionCard }
                }
                .padding(14)
                .id("panel-top")
                .background(GeometryReader { proxy in
                    Color.clear.preference(key: ContentHeightKey.self, value: proxy.size.height)
                })
            }
            .onChange(of: model.topToken) { _, _ in
                proxy.scrollTo("panel-top", anchor: .top)
            }
        }
    }

    private var drawerCard: some View {
        VStack(spacing: 0) {
            drawerRow(L("Movement"), systemImage: "speedometer", detail: model.intervalSummary, page: "movement")
            Divider().padding(.leading, 28)
            drawerRow(L("Settings"), systemImage: "gearshape", detail: nil, page: "settings")
        }
        .cardStyle()
    }

    private func drawerRow(_ title: String, systemImage: String, detail: String?, page: String) -> some View {
        Button {
            model.drawer = page
        } label: {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.medium))
                    if let detail {
                        Text(detail).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(detail ?? "")
        .pointerCursor()
    }

    private func drawerPage(_ kind: String) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                cardTitle(kind == "movement" ? L("Movement") : L("Settings"),
                          systemImage: kind == "movement" ? "speedometer" : "gearshape")
                Spacer(minLength: 8)
                Button {
                    model.drawer = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel(L("Close"))
                .pointerCursor()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            Divider().opacity(0.45)
            ScrollView {
                Group {
                    if kind == "movement" { movementBody } else { settingsBody }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.regularMaterial)
    }

    private var timerBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                cardTitle(L("Timer"), systemImage: "timer")
                Spacer(minLength: 8)
                Picker(L("Timer"), selection: Binding(get: { model.timerKind }, set: {
                    model.timerKind = $0
                    model.timerChanged()
                })) {
                    Text(L("No limit")).tag("none")
                    Text(L("For")).tag("duration")
                    Text(L("Until")).tag("until")
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .fixedSize()
                .pointerCursor()
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    if model.timerKind == "duration" {
                        Text(L("For")).font(.subheadline)
                        Picker(L("Minutes"), selection: Binding(get: { model.minutes }, set: {
                            model.minutes = $0
                            model.timerChanged()
                        })) {
                            ForEach(durationOptions, id: \.self) { value in
                                Text(value, format: .number.precision(.fractionLength(0...1))).tag(value)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 76)
                        .pointerCursor()
                        Text(L("minutes")).font(.subheadline).foregroundStyle(.secondary)
                    } else if model.timerKind == "until" {
                        Text(L("End time")).font(.subheadline)
                        timePickers($model.until, label: L("End time"), onChange: model.timerChanged)
                    } else {
                        Text(L("Runs until you stop it"))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .controlSize(.small)
                .frame(height: 22)
                Text(deadlineText.map { String(format: L("Ends at %@"), $0) } ?? " ")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(height: 14)
                    .accessibilityHidden(deadlineText == nil)
            }
            .frame(height: 44, alignment: .topLeading)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: model.timerKind)
        }
    }

    private var durationOptions: [Double] {
        Set([1, 5, 10, 15, 30, 45, 60, 90, 120, 180, 240, 480, 720, 1440, 10080])
            .union([model.minutes]).sorted()
    }

    private var movementBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text(L("Idle delay")).font(.subheadline).frame(width: 108, alignment: .leading)
                NumberField(value: $model.idleThreshold, range: 1...3600, commit: model.movementChanged)
                Text(L("seconds")).font(.caption).foregroundStyle(.secondary).fixedSize()
                Spacer(minLength: 0)
            }
            HStack(spacing: 6) {
                Text(L("Move every")).font(.subheadline).frame(width: 108, alignment: .leading)
                NumberField(value: $model.intervalLow, range: 1...3600, commit: model.movementChanged)
                Text("–").foregroundStyle(.secondary)
                NumberField(value: $model.intervalHigh, range: 1...3600, commit: model.movementChanged)
                Text(L("seconds")).font(.caption).foregroundStyle(.secondary).fixedSize()
                Spacer(minLength: 0)
            }
            HStack(spacing: 6) {
                Text(L("Pattern")).font(.subheadline).frame(width: 108, alignment: .leading)
                Picker(L("Pattern"), selection: Binding(get: { model.motionPattern }, set: {
                    model.motionPattern = $0
                    model.movementChanged()
                })) {
                    ForEach(Motion.patterns, id: \.self) { pattern in
                        Text(Motion.label(pattern)).tag(pattern)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .pointerCursor()
                Spacer(minLength: 0)
            }
            if model.motionPattern != Motion.defaultPattern {
                HStack(spacing: 6) {
                    Text(L("Radius")).font(.subheadline).frame(width: 108, alignment: .leading)
                    NumberField(value: $model.motionRadius, range: Motion.radiusRange, width: 60,
                                commit: model.movementChanged)
                    Text(L("px")).font(.caption).foregroundStyle(.secondary).fixedSize()
                    Spacer(minLength: 0)
                }
            }
            HStack(spacing: 6) {
                Text(L("Clicks")).font(.subheadline).frame(width: 108, alignment: .leading)
                Picker(L("Clicks"), selection: Binding(get: { model.clickMode }, set: {
                    model.clickMode = $0
                    model.movementChanged()
                })) {
                    Text(L("None")).tag("none")
                    Text(L("Single")).tag("single")
                    Text(L("Double")).tag("double")
                    Text(L("Right")).tag("right")
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .pointerCursor()
                Spacer(minLength: 0)
            }
            HStack(spacing: 6) {
                Text(L("Scroll")).font(.subheadline).frame(width: 108, alignment: .leading)
                Picker(L("Scroll"), selection: Binding(get: { model.scrollMode }, set: {
                    model.scrollMode = $0
                    model.movementChanged()
                })) {
                    Text(L("None")).tag("none")
                    Text(L("Ping")).tag("ping")
                    Text(L("Down")).tag("down")
                    Text(L("Up")).tag("up")
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .pointerCursor()
                Spacer(minLength: 0)
            }
            if model.clickMode != "none" || model.scrollMode != "none" {
                Label(L("Clicks and scrolls land wherever the pointer is"),
                      systemImage: "exclamationmark.triangle")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Button(L("Apply movement"), action: model.movementChanged)
                    .controlSize(.small)
                    .pointerCursor()
                Spacer(minLength: 8)
            }
        }
    }

    private var shortcutRow: some View {
        HStack(spacing: 8) {
            Label(L("Shortcut"), systemImage: "keyboard")
            Spacer(minLength: 8)
            if model.recordingHotkey {
                Text(L("Press a key combination")).font(.caption).foregroundStyle(.secondary)
                Button(L("Cancel"), action: model.recordHotkey).controlSize(.small).pointerCursor()
            } else {
                Text(model.hotkeyDisplay.isEmpty ? "—" : model.hotkeyDisplay)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
                Button(L("Record"), action: model.recordHotkey).controlSize(.small).pointerCursor()
            }
        }
    }

    private var displaySetting: some View {
        HStack(spacing: 10) {
            Image(systemName: "display")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Keep display awake")).font(.subheadline.weight(.medium))
                Text(model.status.displayAssertion ? L("Screen stays on while active") : L("Normal display sleep"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: Binding(get: { model.preventDisplaySleep }, set: { _ in model.screen() }))
                .labelsHidden()
                .toggleStyle(.switch)
                .accessibilityLabel(L("Keep display awake"))
                .pointerCursor()
        }
        .controlSize(.small)
    }

    private var dimSetting: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: model.dimWhileActive ? "sun.min" : "sun.max")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("Dim the display")).font(.subheadline.weight(.medium))
                    Text(dimSummary).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: Binding(get: { model.dimWhileActive }, set: { value in
                    model.dimWhileActive = value
                    model.dimChanged()
                }))
                .labelsHidden()
                .toggleStyle(.switch)
                .accessibilityLabel(L("Dim the display"))
                .disabled(!model.preventDisplaySleep || !model.brightnessSupported)
                .pointerCursor()
            }
            HStack(spacing: 8) {
                Image(systemName: "sun.min")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Slider(value: Binding(get: { model.dimBrightness }, set: { value in
                    model.dimBrightness = value
                    model.dimPreview()
                }), in: 0.05...1, onEditingChanged: { editing in
                    if !editing { model.dimChanged() }
                })
                .controlSize(.small)
                .disabled(!model.dimWhileActive || !model.preventDisplaySleep)
                .accessibilityLabel(L("Brightness"))
                .pointerCursor()
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(String(format: "%d%%", Int((model.dimBrightness * 100).rounded())))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 34, alignment: .trailing)
            }
            .padding(.leading, 2)
        }
        .controlSize(.small)
    }

    private var dimSummary: String {
        if !model.brightnessSupported { return L("This display does not allow brightness control") }
        if !model.preventDisplaySleep { return L("Keep the display awake to dim it") }
        guard model.dimWhileActive else { return L("Normal brightness") }
        return String(format: L("Dimmed to %d%% while GiGi is active"), Int((model.dimBrightness * 100).rounded()))
    }

    private var notificationsSetting: some View {
        HStack(spacing: 10) {
            Image(systemName: model.notificationsEnabled ? "bell.fill" : "bell.slash")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Notifications")).font(.subheadline.weight(.medium))
                Text(notificationsSummary).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle(L("Notifications"), isOn: Binding(get: { model.notificationsEnabled }, set: { value in
                model.notificationsEnabled = value
                model.notificationsChanged()
            }))
            .labelsHidden()
            .toggleStyle(.switch)
            .pointerCursor()
        }
        .controlSize(.small)
    }

    private var notificationsSummary: String {
        guard model.notificationsEnabled else { return L("Silent") }
        if model.notificationsDenied { return L("Blocked in System Settings") }
        return L("Warn me when GiGi stops on its own")
    }

    private var modeRow: some View {
        HStack {
            Label(L("Mode"), systemImage: "arrow.triangle.2.circlepath")
                .font(.subheadline.weight(.medium))
            Spacer()
            Picker(L("Mode"), selection: Binding(get: { model.mode }, set: {
                model.mode = $0
                model.modeChanged($0)
            })) {
                Text(L("Schedule")).tag("schedule")
                Text(L("Always")).tag("always")
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .pointerCursor()
        }
    }

    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            scheduleBody
            Divider()
            timerBody
            Divider()
            batteryBody
            Divider()
            modeRow
        }
        .cardStyle()
    }

    private var batteryBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                cardTitle(L("Battery limit"), systemImage: "battery.25percent")
                Spacer(minLength: 8)
                Toggle(L("Battery limit"), isOn: Binding(get: { model.batteryLimitEnabled }, set: {
                    model.batteryLimitEnabled = $0
                    model.batteryChanged()
                }))
                .labelsHidden()
                .toggleStyle(.switch)
                .pointerCursor()
            }
            HStack(spacing: 8) {
                Text(L("Stop GiGi at")).font(.subheadline)
                Picker(L("Battery percentage"), selection: Binding(get: { model.batteryLimitPercent }, set: {
                    model.batteryLimitPercent = $0
                    model.batteryChanged()
                })) {
                    ForEach(batteryChoices, id: \.self) { percent in
                        Text("\(percent)%").tag(percent)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                .frame(width: 68)
                .pointerCursor()
                Spacer(minLength: 0)
            }
            .disabled(!model.batteryLimitEnabled)
            Text(L("Only while using battery power"))
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var batteryChoices: [Int] {
        Set(Config.batteryLimitChoices).union([model.batteryLimitPercent]).sorted()
    }

    private var appConditionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                cardTitle(L("Only while an app…"), systemImage: "app.dashed")
                Spacer(minLength: 8)
                Toggle(L("Only while an app…"), isOn: Binding(get: { model.appCondition.enabled }, set: {
                    model.appCondition.enabled = $0
                    model.appConditionChanged()
                }))
                .labelsHidden()
                .toggleStyle(.switch)
                .pointerCursor()
            }
            Picker(L("App condition"), selection: Binding(get: { model.appCondition.mode }, set: {
                model.appCondition.mode = $0
                model.appConditionChanged()
            })) {
                Text(L("Is running")).tag("running")
                Text(L("Is in front")).tag("frontmost")
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .disabled(!model.appCondition.enabled)
            ForEach(model.appCondition.apps) { app in
                HStack(spacing: 8) {
                    Image(nsImage: appIcon(app.id))
                        .resizable().frame(width: 22, height: 22)
                        .accessibilityHidden(true)
                    Text(app.name).font(.subheadline).lineLimit(1)
                    Spacer(minLength: 8)
                    Button {
                        model.appCondition.apps.removeAll { $0.id == app.id }
                        model.appConditionChanged()
                    } label: {
                        Image(systemName: "minus.circle").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(format: L("Remove %@"), app.name))
                    .pointerCursor()
                }
            }
            HStack(spacing: 8) {
                Button(action: model.addApp) {
                    Label(L("Add app"), systemImage: "plus")
                }
                .controlSize(.small)
                .pointerCursor()
                if model.appCondition.apps.isEmpty {
                    Text(L("Choose an app to watch"))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if !model.appCondition.apps.isEmpty {
                Text(L("Any selected app can enable activity"))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .cardStyle()
    }

    private func appIcon(_ id: String) -> NSImage {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else {
            return NSImage(systemSymbolName: "app", accessibilityDescription: nil) ?? NSImage()
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    private var scheduleBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                cardTitle(L("Schedule"), systemImage: "calendar")
                Spacer(minLength: 8)
                Toggle("", isOn: Binding(get: { model.scheduleEnabled }, set: { value in
                    model.scheduleEnabled = value
                    model.scheduleChanged()
                }))
                .labelsHidden()
                .toggleStyle(.switch)
                .accessibilityLabel(L("Schedule"))
                .pointerCursor()
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 4) {
                    Text(L("From")).font(.subheadline).fixedSize()
                    timePickers($model.scheduleStart, label: L("From"), onChange: model.scheduleChanged)
                    Text(L("To")).font(.subheadline).padding(.leading, 4).fixedSize()
                    timePickers($model.scheduleEnd, label: L("To"), onChange: model.scheduleChanged)
                    Spacer(minLength: 0)
                }
                HStack(spacing: 5) {
                    Text(L("Repeat")).font(.subheadline)
                    Spacer(minLength: 4)
                    ForEach(weekdayNames, id: \.self) { day in
                        dayChip(day)
                    }
                }
                if model.scheduleDays.isEmpty {
                    Text(L("Select at least one day"))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .disabled(!model.scheduleEnabled)
            .opacity(model.scheduleEnabled ? 1 : 0.5)
            if model.scheduleEnabled && model.mode == "always" {
                Label(L("Mode Always is ignoring this window"), systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(L("Mode Always is ignoring this window"))
            }
            if model.scheduleWindows > 1 {
                Text(String(format: L("+%d more windows in the configuration file"), model.scheduleWindows - 1))
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func timePickers(_ date: Binding<Date>, label: String, onChange: @escaping () -> Void) -> some View {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date.wrappedValue)
        let minute = calendar.component(.minute, from: date.wrappedValue)
        let minutes = Set(stride(from: 0, to: 60, by: 5)).union([minute]).sorted()
        return HStack(spacing: 3) {
            Picker(String(format: L("%@ hour"), label), selection: Binding(get: { hour }, set: { value in
                date.wrappedValue = time(of: date.wrappedValue, hour: value, minute: minute)
                onChange()
            })) {
                ForEach(0...23, id: \.self) { value in
                    Text(String(format: "%02d", value)).tag(value)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 48)
            .pointerCursor()
            Picker(String(format: L("%@ minute"), label), selection: Binding(get: { minute }, set: { value in
                date.wrappedValue = time(of: date.wrappedValue, hour: hour, minute: value)
                onChange()
            })) {
                ForEach(minutes, id: \.self) { value in
                    Text(String(format: "%02d", value)).tag(value)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 48)
            .pointerCursor()
        }
        .controlSize(.small)
    }

    private func time(of date: Date, hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        var comps = calendar.dateComponents([.year, .month, .day], from: date)
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        return calendar.date(from: comps) ?? date
    }

    private func dayChip(_ day: String) -> some View {
        let selected = model.scheduleDays.contains(day)
        return Button {
            if selected {
                guard model.scheduleDays.count > 1 else { return }
                model.scheduleDays.remove(day)
            } else {
                model.scheduleDays.insert(day)
            }
            model.scheduleChanged()
        } label: {
            Text(L(dayLabel(day)))
                .font(.caption.weight(.medium))
                .frame(width: 27, height: 21)
                .background(selected ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary), in: RoundedRectangle(cornerRadius: 5))
                .foregroundStyle(selected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .pointerCursor()
    }

    private func dayLabel(_ day: String) -> String {
        switch day {
        case "sun": return "Su"
        case "mon": return "Mo"
        case "tue": return "Tu"
        case "wed": return "We"
        case "thu": return "Th"
        case "fri": return "Fr"
        default: return "Sa"
        }
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L("Accessibility permission needed"), systemImage: "hand.raised.fill")
                .font(.subheadline.weight(.semibold))
            Text(L("GiGi needs Accessibility permission to move the cursor."))
                .font(.caption).foregroundStyle(.secondary)
            Button(L("Open Accessibility settings"), action: model.accessibility)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .pointerCursor()
        }
        .cardStyle()
        .tint(.orange)
    }

    private var settingsBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(L("Start at login"), systemImage: "power")
                Spacer()
                Toggle(L("Start at login"), isOn: Binding(get: { model.login }, set: {
                    model.login = $0
                    model.loginChanged()
                }))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .pointerCursor()
            }
            displaySetting
            dimSetting
            Divider()
            notificationsSetting
            Divider()
            shortcutRow
            Divider()
            HStack {
                Label(L("Language"), systemImage: "globe")
                Spacer(minLength: 8)
                Picker(L("Language"), selection: Binding(get: { model.language }, set: {
                    model.language = $0
                    model.preferencesChanged()
                })) {
                    Text(L("System")).tag("system")
                    Text("English").tag("en")
                    Text("Español").tag("es")
                }
                .labelsHidden()
                .frame(width: 132)
                .pointerCursor()
            }
            HStack {
                Label(L("Appearance"), systemImage: "circle.lefthalf.filled")
                Spacer(minLength: 8)
                Picker(L("Appearance"), selection: Binding(get: { model.theme }, set: {
                    model.theme = $0
                    model.preferencesChanged()
                })) {
                    Text(L("System")).tag("system")
                    Text(L("Light")).tag("light")
                    Text(L("Dark")).tag("dark")
                }
                .labelsHidden()
                .frame(width: 132)
                .pointerCursor()
            }
            Divider()
            settingsAction("Open log", symbol: "doc.text", action: model.log)
            DisclosureGroup(L("Advanced")) {
                VStack(alignment: .leading, spacing: 10) {
                    settingsAction("Reload configuration", symbol: "arrow.clockwise", action: model.reload)
                    settingsAction("Open configuration folder", symbol: "folder", action: model.configFolder)
                }
                .padding(.top, 8)
            }
        }
        .pickerStyle(.menu)
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func settingsAction(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Label(L(title), systemImage: symbol)
                Spacer(minLength: 4)
                Image(systemName: "arrow.up.forward").foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointerCursor()
    }

    private var footer: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: L("%d movements"), model.status.jiggles))                        .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                if let idle = model.status.lastIdle {
                    Text(String(format: L("Idle %.0fs"), idle)).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(action: model.move) {
                Label(L("Move now"), systemImage: "cursorarrow.motionlines")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(!model.status.accessibilityTrusted)
            .pointerCursor(model.status.accessibilityTrusted)
            Menu {
                Button(L("Quit"), action: model.quit)
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 24)
            .pointerCursor()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(GeometryReader { proxy in
            Color.clear.preference(key: FooterHeightKey.self, value: proxy.size.height)
        })
    }

    private func cardTitle(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
    }
}

private struct NumberField: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var width: CGFloat = 60
    let commit: () -> Void

    @State private var text = ""
    @FocusState private var editing: Bool

    var body: some View {
        TextField("", text: $text)
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
            .frame(width: width)
            .focused($editing)
            .onAppear { text = display(value) }
            .onChange(of: value) { _, new in
                if !editing { text = display(new) }
            }
            .onChange(of: editing) { _, isEditing in
                if !isEditing { apply() }
            }
            .onSubmit { apply() }
    }

    private func display(_ number: Double) -> String {
        guard number.isFinite else { return "0" }
        return String(format: "%.0f", number)
    }

    private func apply() {
        let typed = text.filter(\.isNumber)
        guard let parsed = Double(typed) else {
            text = display(value)
            return
        }
        let limited = min(range.upperBound, max(range.lowerBound, parsed.rounded()))
        text = display(limited)
        guard limited != value else { return }
        value = limited
        commit()
    }
}

private extension View {
    func cardStyle() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.quaternary.opacity(0.34), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    func pointerCursor(_ enabled: Bool = true) -> some View {
        if #available(macOS 15.0, *) {
            pointerStyle(enabled ? .link : .default)
        } else {
            onHover { hovering in
                guard hovering else { return }
                if enabled { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
            }
        }
    }
}
