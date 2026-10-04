import SwiftUI

private struct HeaderHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 60
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct FooterHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 44
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct DrawerHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

final class PanelModel: ObservableObject {
    @Published var status = Engine.Status()
    @Published private var headerHeight: CGFloat = 60
    @Published private var footerHeight: CGFloat = 44
    @Published private var contentHeight: CGFloat = 0
    @Published private var drawerHeight: CGFloat = 0
    @Published var maxHeight: CGFloat = 520

    var panelHeight: CGFloat {
        let body = drawer == nil ? contentHeight : drawerHeight
        return min(maxHeight, headerHeight + footerHeight + 1 + max(body, 240))
    }

    private func adjust(_ value: CGFloat, _ stored: CGFloat) -> Bool {
        abs(value - stored) > 0.5
    }

    func setMetrics(header: CGFloat? = nil, footer: CGFloat? = nil, content: CGFloat? = nil, drawer: CGFloat? = nil) {
        var changed = false
        if let header, adjust(header, headerHeight) { headerHeight = header; changed = true }
        if let footer, adjust(footer, footerHeight) { footerHeight = footer; changed = true }
        if let content, adjust(content, contentHeight) { contentHeight = content; changed = true }
        if let drawer, adjust(drawer, drawerHeight) { drawerHeight = drawer; changed = true }
        if changed { heightChanged() }
    }

    var heightChanged: () -> Void = {}
    @Published var preventDisplaySleep = true
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
    @Published var turnOffKeyboardLight = false
    @Published var batteryLimitEnabled = false
    @Published var batteryLimitPercent = 20
    var batteryChanged: () -> Void = {}
    @Published var notificationsEnabled = true
    @Published var notificationsDenied = false
    var notificationsChanged: () -> Void = {}
    @Published var version = BuildVersion.current
    @Published var checkForUpdates = true
    @Published var update: UpdateStatus = .idle
    var checkForUpdatesChanged: () -> Void = {}
    var checkForUpdatesNow: () -> Void = {}
    var openReleasePage: () -> Void = {}
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
    @Published var drawer: String? {
        didSet { if drawer != oldValue { heightChanged() } }
    }
    @Published var topToken = UUID()
    @Published var error: String?

    var brightnessSupported: Bool { status.brightness != nil }
    var keyboardLightSupported: Bool { status.keyboardBrightness != nil }

    var toggle: () -> Void = {}
    var screen: () -> Void = {}
    var timerChanged: () -> Void = {}
    var movementChanged: () -> Void = {}
    var dimPreview: () -> Void = {}
    var dimChanged: () -> Void = {}
    var keyboardLightChanged: () -> Void = {}
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

    private var locale: Locale {
        model.language == "system" ? .autoupdatingCurrent : Locale(identifier: model.language)
    }

    private var expand: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.18)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ZStack(alignment: .top) {
                mainList
                    .offset(x: model.drawer == nil ? 0 : -360)
                    .opacity(model.drawer == nil ? 1 : 0)
                    .allowsHitTesting(model.drawer == nil)
                    .accessibilityHidden(model.drawer != nil)
                if let drawer = model.drawer {
                    drawerPage(drawer)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .clipped()
            .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.88), value: model.drawer)
            Divider()
            footer
        }
        .frame(width: 360, height: model.panelHeight)
        .preferredColorScheme(model.theme == "dark" ? .dark : model.theme == "light" ? .light : nil)
        .environment(\.locale, locale)
        .onPreferenceChange(HeaderHeightKey.self) { height in
            DispatchQueue.main.async { model.setMetrics(header: height) }
        }
        .onPreferenceChange(FooterHeightKey.self) { height in
            DispatchQueue.main.async { model.setMetrics(footer: height) }
        }
        .onPreferenceChange(ContentHeightKey.self) { height in
            DispatchQueue.main.async { model.setMetrics(content: height) }
        }
        .onPreferenceChange(DrawerHeightKey.self) { height in
            DispatchQueue.main.async { model.setMetrics(drawer: height) }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            StateGlyph(state: StatusIcon.state(for: model.status))
            VStack(alignment: .leading, spacing: 1) {
                Text(statusLabel).font(.headline)
                Text(headerDetail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: Binding(get: { model.status.running }, set: { _ in model.toggle() }))
                .labelsHidden()
                .toggleStyle(.switch)
                .accessibilityLabel(L("GiGi active"))
                .pointerCursor()
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
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

    private var headerDetail: String {
        let movements = String(format: L("%d movements"), model.status.jiggles)
        guard let deadline = model.status.deadline else { return movements }
        let time = deadline.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale))
        return String(format: L("Ends at %@"), time) + " · " + movements
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if let idle = model.status.lastIdle {
                Text(String(format: L("Idle %.0fs"), idle))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: model.move) {
                Label(L("Move now"), systemImage: "cursorarrow.motionlines")
            }
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
            .fixedSize()
            .accessibilityLabel(L("More"))
            .pointerCursor()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(GeometryReader { proxy in
            Color.clear.preference(key: FooterHeightKey.self, value: proxy.size.height)
        })
    }

    private var mainList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if !model.status.accessibilityTrusted { permissionSection }
                    whenSection
                    appConditionSection
                    PanelSection {
                        navigationRow(L("Movement"), symbol: "point.topleft.down.to.point.bottomright.curvepath",
                                      detail: model.intervalSummary, page: "movement")
                        RowDivider()
                        navigationRow(L("Settings"), symbol: "gearshape", detail: nil, page: "settings")
                    }
                    errorLabel
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .padding(.bottom, 12)
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

    @ViewBuilder
    private var errorLabel: some View {
        if let error = model.error {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 10)
        }
    }

    private var permissionSection: some View {
        PanelSection {
            SettingRow(title: L("Accessibility permission needed"), symbol: "hand.raised.fill",
                       detail: L("GiGi needs Accessibility permission to move the cursor.")) {
                EmptyView()
            }
            RowDetail {
                Button(L("Open Accessibility settings"), action: model.accessibility)
                    .pointerCursor()
            }
        }
    }

    private var whenSection: some View {
        PanelSection {
            toggleRow(L("Schedule"), symbol: "calendar", isOn: Binding(get: { model.scheduleEnabled }, set: {
                model.scheduleEnabled = $0
                model.scheduleChanged()
            }))
            if model.scheduleEnabled { scheduleDetail }
            RowDivider()
            SettingRow(title: L("Timer"), symbol: "timer") {
                Picker(L("Timer"), selection: Binding(get: { model.timerKind }, set: {
                    model.timerKind = $0
                    model.timerChanged()
                })) {
                    Text(L("No limit")).tag("none")
                    Text(L("For")).tag("duration")
                    Text(L("Until")).tag("until")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .pointerCursor()
            }
            if model.timerKind != "none" { timerDetail }
            RowDivider()
            toggleRow(L("Battery limit"), symbol: "battery.25percent",
                      detail: L("Only while using battery power"),
                      isOn: Binding(get: { model.batteryLimitEnabled }, set: {
                          model.batteryLimitEnabled = $0
                          model.batteryChanged()
                      }))
            if model.batteryLimitEnabled {
                RowDetail {
                    Text(L("Stop GiGi at")).foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Picker(L("Battery percentage"), selection: Binding(get: { model.batteryLimitPercent }, set: {
                        model.batteryLimitPercent = $0
                        model.batteryChanged()
                    })) {
                        ForEach(batteryChoices, id: \.self) { percent in
                            Text("\(percent)%").tag(percent)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                    .pointerCursor()
                }
            }
        }
        .animation(expand, value: model.scheduleEnabled)
        .animation(expand, value: model.timerKind)
        .animation(expand, value: model.batteryLimitEnabled)
    }

    private var scheduleDetail: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                timeField(Binding(get: { model.scheduleStart }, set: {
                    model.scheduleStart = $0
                    model.scheduleChanged()
                }), label: L("From"))
                Text("–").foregroundStyle(.secondary)
                timeField(Binding(get: { model.scheduleEnd }, set: {
                    model.scheduleEnd = $0
                    model.scheduleChanged()
                }), label: L("To"))
                Spacer(minLength: 0)
            }
            HStack(spacing: 4) {
                ForEach(weekdayNames, id: \.self) { day in
                    dayChip(day)
                }
            }
            if model.scheduleDays.isEmpty {
                Text(L("Select at least one day")).font(.caption).foregroundStyle(.secondary)
            }
            if model.scheduleWindows > 1 {
                Text(String(format: L("+%d more windows in the configuration file"), model.scheduleWindows - 1))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.leading, RowMetrics.textInset)
        .padding(.trailing, RowMetrics.padding)
        .padding(.bottom, 10)
    }

    private var timerDetail: some View {
        RowDetail {
            if model.timerKind == "duration" {
                Picker(L("Minutes"), selection: Binding(get: { model.minutes }, set: {
                    model.minutes = $0
                    model.timerChanged()
                })) {
                    ForEach(durationOptions, id: \.self) { value in
                        Text(durationText(value)).tag(value)
                    }
                }
                .labelsHidden()
                .fixedSize()
                .pointerCursor()
            } else {
                timeField(Binding(get: { model.until }, set: {
                    model.until = $0
                    model.timerChanged()
                }), label: L("End time"))
            }
            Spacer(minLength: 8)
            if let deadline = model.status.deadline {
                Text(String(format: L("Ends at %@"),
                            deadline.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale))))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var durationOptions: [Double] {
        Set([1, 5, 10, 15, 30, 45, 60, 90, 120, 180, 240, 480, 720, 1440, 10080])
            .union([model.minutes]).sorted()
    }

    private func durationText(_ minutes: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        var calendar = Calendar.current
        calendar.locale = locale
        formatter.calendar = calendar
        return formatter.string(from: minutes * 60) ?? String(format: "%.0f", minutes)
    }

    private var batteryChoices: [Int] {
        Set(Config.batteryLimitChoices).union([model.batteryLimitPercent]).sorted()
    }

    private func timeField(_ date: Binding<Date>, label: String) -> some View {
        DatePicker(label, selection: date, displayedComponents: .hourAndMinute)
            .datePickerStyle(.field)
            .labelsHidden()
            .fixedSize()
            .accessibilityLabel(label)
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
                .frame(width: 30, height: 22)
                .background(selected ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary),
                            in: RoundedRectangle(cornerRadius: 6, style: .continuous))
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

    private var appConditionSection: some View {
        PanelSection {
            toggleRow(L("Only while an app…"), symbol: "app.dashed",
                      detail: model.appCondition.enabled ? L("Any selected app can enable activity") : nil,
                      isOn: Binding(get: { model.appCondition.enabled }, set: {
                          model.appCondition.enabled = $0
                          model.appConditionChanged()
                      }))
            if model.appCondition.enabled {
                VStack(alignment: .leading, spacing: 8) {
                    Picker(L("App condition"), selection: Binding(get: { model.appCondition.mode }, set: {
                        model.appCondition.mode = $0
                        model.appConditionChanged()
                    })) {
                        Text(L("Is running")).tag("running")
                        Text(L("Is in front")).tag("frontmost")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                    ForEach(model.appCondition.apps) { app in
                        HStack(spacing: 8) {
                            Image(nsImage: appIcon(app.id))
                                .resizable().frame(width: 18, height: 18)
                                .accessibilityHidden(true)
                            Text(app.name).lineLimit(1)
                            Spacer(minLength: 8)
                            Button {
                                model.appCondition.apps.removeAll { $0.id == app.id }
                                model.appConditionChanged()
                            } label: {
                                Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
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
                            Text(L("Choose an app to watch")).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.leading, RowMetrics.textInset)
                .padding(.trailing, RowMetrics.padding)
                .padding(.bottom, 10)
            }
        }
        .animation(expand, value: model.appCondition.enabled)
    }

    private func appIcon(_ id: String) -> NSImage {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else {
            return NSImage(systemSymbolName: "app", accessibilityDescription: nil) ?? NSImage()
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    private func navigationRow(_ title: String, symbol: String, detail: String?, page: String) -> some View {
        Button {
            model.drawer = page
        } label: {
            SettingRow(title: title, symbol: symbol, detail: detail) {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(detail ?? "")
        .pointerCursor()
    }

    private func drawerPage(_ kind: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    model.drawer = nil
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left").font(.body.weight(.semibold))
                        Text(kind == "movement" ? L("Movement") : L("Settings")).font(.headline)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel(L("Close"))
                .pointerCursor()
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                if kind == "movement" { movementBody } else { settingsBody }
                errorLabel
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .padding(.bottom, 12)
            .background(GeometryReader { proxy in
                Color.clear.preference(key: DrawerHeightKey.self, value: proxy.size.height)
            })
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var movementBody: some View {
        Group {
            PanelSection {
                SettingRow(title: L("Idle delay"), symbol: "hourglass") {
                    NumberField(value: $model.idleThreshold, range: 1...3600, commit: model.movementChanged)
                    unit(L("seconds"))
                }
                RowDivider()
                SettingRow(title: L("Move every"), symbol: "repeat") {
                    NumberField(value: $model.intervalLow, range: 1...3600, commit: model.movementChanged)
                    Text("–").foregroundStyle(.secondary)
                    NumberField(value: $model.intervalHigh, range: 1...3600, commit: model.movementChanged)
                    unit(L("seconds"))
                }
            }
            PanelSection {
                SettingRow(title: L("Pattern"), symbol: "scribble.variable") {
                    menuPicker(L("Pattern"), selection: Binding(get: { model.motionPattern }, set: {
                        model.motionPattern = $0
                        model.movementChanged()
                    })) {
                        ForEach(Motion.patterns, id: \.self) { pattern in
                            Text(Motion.label(pattern)).tag(pattern)
                        }
                    }
                }
                if model.motionPattern != Motion.defaultPattern {
                    RowDivider()
                    SettingRow(title: L("Radius"), symbol: "circle.dashed") {
                        NumberField(value: $model.motionRadius, range: Motion.radiusRange, commit: model.movementChanged)
                        unit(L("px"))
                    }
                }
            }
            PanelSection {
                SettingRow(title: L("Clicks"), symbol: "cursorarrow.click") {
                    menuPicker(L("Clicks"), selection: Binding(get: { model.clickMode }, set: {
                        model.clickMode = $0
                        model.movementChanged()
                    })) {
                        Text(L("None")).tag("none")
                        Text(L("Single")).tag("single")
                        Text(L("Double")).tag("double")
                        Text(L("Right")).tag("right")
                    }
                }
                RowDivider()
                SettingRow(title: L("Scroll"), symbol: "scroll",
                           detail: model.clickMode != "none" || model.scrollMode != "none"
                               ? L("Clicks and scrolls land wherever the pointer is") : nil) {
                    menuPicker(L("Scroll"), selection: Binding(get: { model.scrollMode }, set: {
                        model.scrollMode = $0
                        model.movementChanged()
                    })) {
                        Text(L("None")).tag("none")
                        Text(L("Ping")).tag("ping")
                        Text(L("Down")).tag("down")
                        Text(L("Up")).tag("up")
                    }
                }
            }
        }
    }

    private var settingsBody: some View {
        Group {
            PanelSection {
                toggleRow(L("Start at login"), symbol: "power", isOn: Binding(get: { model.login }, set: {
                    model.login = $0
                    model.loginChanged()
                }))
                RowDivider()
                toggleRow(L("Notifications"), symbol: "bell", detail: notificationsSummary,
                          isOn: Binding(get: { model.notificationsEnabled }, set: {
                              model.notificationsEnabled = $0
                              model.notificationsChanged()
                          }))
                RowDivider()
                shortcutRow
            }
            PanelSection {
                toggleRow(L("Keep display awake"), symbol: "display",
                          detail: model.status.displayAssertion ? L("Screen stays on while active") : L("Normal display sleep"),
                          isOn: Binding(get: { model.preventDisplaySleep }, set: { _ in model.screen() }))
                RowDivider()
                toggleRow(L("Dim the display"), symbol: "sun.min", detail: dimSummary,
                          isOn: Binding(get: { model.dimWhileActive }, set: {
                              model.dimWhileActive = $0
                              model.dimChanged()
                          }))
                    .disabled(!model.preventDisplaySleep || !model.brightnessSupported)
                if model.dimWhileActive && model.preventDisplaySleep && model.brightnessSupported { dimSlider }
                RowDivider()
                toggleRow(L("Turn off the keyboard light"), symbol: "light.min", detail: keyboardSummary,
                          isOn: Binding(get: { model.turnOffKeyboardLight }, set: {
                              model.turnOffKeyboardLight = $0
                              model.keyboardLightChanged()
                          }))
                    .disabled(!model.keyboardLightSupported)
            }
            .animation(expand, value: model.dimWhileActive)
            PanelSection {
                SettingRow(title: L("Language"), symbol: "globe") {
                    menuPicker(L("Language"), selection: Binding(get: { model.language }, set: {
                        model.language = $0
                        model.preferencesChanged()
                    })) {
                        Text(L("System")).tag("system")
                        Text("English").tag("en")
                        Text("Español").tag("es")
                    }
                }
                RowDivider()
                SettingRow(title: L("Appearance"), symbol: "circle.lefthalf.filled") {
                    menuPicker(L("Appearance"), selection: Binding(get: { model.theme }, set: {
                        model.theme = $0
                        model.preferencesChanged()
                    })) {
                        Text(L("System")).tag("system")
                        Text(L("Light")).tag("light")
                        Text(L("Dark")).tag("dark")
                    }
                }
            }
            PanelSection {
                SettingRow(title: L("Version"), symbol: "info.circle") {
                    Text(model.version).monospacedDigit().foregroundStyle(.secondary)
                }
                RowDivider()
                toggleRow(L("Check for updates automatically"), symbol: "arrow.triangle.2.circlepath",
                          isOn: Binding(get: { model.checkForUpdates }, set: {
                              model.checkForUpdates = $0
                              model.checkForUpdatesChanged()
                          }))
                RowDivider()
                updateStatusRow
            }
            PanelSection {
                actionRow("Open log", symbol: "doc.text", action: model.log)
                RowDivider()
                actionRow("Reload configuration", symbol: "arrow.clockwise", action: model.reload)
                RowDivider()
                actionRow("Open configuration folder", symbol: "folder", action: model.configFolder)
            }
        }
    }

    private var shortcutRow: some View {
        SettingRow(title: L("Shortcut"), symbol: "command",
                   detail: model.recordingHotkey ? L("Press a key combination") : nil) {
            if model.recordingHotkey {
                Button(L("Cancel"), action: model.recordHotkey).controlSize(.small).pointerCursor()
            } else {
                Text(model.hotkeyDisplay.isEmpty ? "—" : model.hotkeyDisplay)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                Button(L("Record"), action: model.recordHotkey).controlSize(.small).pointerCursor()
            }
        }
    }

    private var dimSlider: some View {
        RowDetail {
            Image(systemName: "sun.min").font(.caption).foregroundStyle(.secondary)
            Slider(value: Binding(get: { model.dimBrightness }, set: { value in
                model.dimBrightness = value
                model.dimPreview()
            }), in: 0...1, onEditingChanged: { editing in
                if !editing { model.dimChanged() }
            })
            .controlSize(.small)
            .accessibilityLabel(L("Brightness"))
            .pointerCursor()
            Image(systemName: "sun.max").font(.caption).foregroundStyle(.secondary)
            Text(String(format: "%d%%", Int((model.dimBrightness * 100).rounded())))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)
        }
    }

    private var dimSummary: String {
        if !model.brightnessSupported { return L("This display does not allow brightness control") }
        if !model.preventDisplaySleep { return L("Keep the display awake to dim it") }
        guard model.dimWhileActive else { return L("Normal brightness") }
        return String(format: L("Dimmed to %d%% while GiGi is active"), Int((model.dimBrightness * 100).rounded()))
    }

    private var keyboardSummary: String {
        if !model.keyboardLightSupported { return L("This Mac does not allow keyboard light control") }
        guard model.turnOffKeyboardLight else { return L("Normal keyboard light") }
        return L("Keyboard light off while GiGi is active")
    }

    private var notificationsSummary: String {
        guard model.notificationsEnabled else { return L("Silent") }
        if model.notificationsDenied { return L("Blocked in System Settings") }
        return L("Warn me when GiGi stops on its own")
    }

    @ViewBuilder
    private var updateStatusRow: some View {
        switch model.update {
        case .idle:
            actionRow("Check now", symbol: "arrow.down.circle", action: model.checkForUpdatesNow)
        case .checking:
            SettingRow(title: L("Checking for updates…"), symbol: "arrow.down.circle") {
                ProgressView().controlSize(.small)
            }
        case .upToDate:
            SettingRow(title: L("GiGi is up to date"), symbol: "checkmark.circle") {
                EmptyView()
            }
        case .available(let version):
            SettingRow(title: String(format: L("GiGi %@ is available"), version), symbol: "gift") {
                Button(L("View release"), action: model.openReleasePage).controlSize(.small).pointerCursor()
            }
        case .failed(let reason):
            SettingRow(title: reason, symbol: "exclamationmark.triangle") {
                Button(L("Check now"), action: model.checkForUpdatesNow).controlSize(.small).pointerCursor()
            }
        }
    }

    private func toggleRow(_ title: String, symbol: String, detail: String? = nil, isOn: Binding<Bool>) -> some View {
        SettingRow(title: title, symbol: symbol, detail: detail) {
            Toggle(title, isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .pointerCursor()
        }
    }

    private func actionRow(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            SettingRow(title: L(title), symbol: symbol) {
                Image(systemName: "arrow.up.forward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointerCursor()
    }

    private func menuPicker<Value: Hashable, Options: View>(
        _ title: String, selection: Binding<Value>, @ViewBuilder options: () -> Options
    ) -> some View {
        Picker(title, selection: selection, content: options)
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
            .pointerCursor()
    }

    private func unit(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(.secondary).fixedSize()
    }
}

private struct StateGlyph: View {
    let state: StatusIcon.State

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(state == .inactive ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.tint.opacity(0.18)))
            Image(nsImage: StatusIcon.image(for: state))
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32)
                .foregroundStyle(state == .inactive ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
            Image(nsImage: StatusIcon.badge(for: state))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32)
        }
        .frame(width: 36, height: 36)
        .animation(.easeInOut(duration: 0.2), value: state)
        .accessibilityHidden(true)
    }
}

private struct PanelSection<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quinary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private enum RowMetrics {
    static let padding: CGFloat = 10
    static let textInset: CGFloat = padding + 20 + 10
}

private struct SettingRow<Accessory: View>: View {
    let title: String
    let symbol: String
    var detail: String? = nil
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 20)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            HStack(spacing: 6) { accessory }
                .controlSize(.small)
                .fixedSize()
        }
        .padding(.horizontal, RowMetrics.padding)
        .padding(.vertical, 8)
        .frame(minHeight: 38)
    }
}

private struct RowDetail<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 8) { content }
            .controlSize(.small)
            .padding(.leading, RowMetrics.textInset)
            .padding(.trailing, RowMetrics.padding)
            .padding(.bottom, 10)
    }
}

private struct RowDivider: View {
    var body: some View {
        Divider().padding(.leading, RowMetrics.textInset)
    }
}

private struct NumberField: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var width: CGFloat = 44
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
            .onDisappear { apply() }
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
