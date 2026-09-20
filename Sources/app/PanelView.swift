import SwiftUI

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
    @Published var clickMode = "none"
    @Published var scrollMode = "none"
    @Published var hotkey: String = Hotkey.default.config
    @Published var hotkeyDisplay: String = Hotkey.default.display
    @Published var recordingHotkey = false
    @Published var intervalSummary = ""
    @Published var drawer: String?
    @Published var topToken = UUID()
    @Published var error: String?

    var toggle: () -> Void = {}
    var screen: () -> Void = {}
    var modeChanged: (String) -> Void = { _ in }
    var timerChanged: () -> Void = {}
    var movementChanged: () -> Void = {}
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
            Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSImage())
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
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(GeometryReader { proxy in
            Color.clear.preference(key: HeaderHeightKey.self, value: proxy.size.height)
        })
    }

    private var statusLabel: String {
        if !model.status.accessibilityTrusted {
            return model.status.displayAssertion ? L("Screen awake · permission pending") : L("Accessibility permission needed")
        }
        if model.status.running && model.status.outOfSchedule { return L("Waiting for schedule") }
        return model.status.running ? L("Active") : L("Inactive")
    }

    private var mainList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    timerCard
                    drawerCard
                    modeCard
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

    private var timerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardTitle(L("Timer"), systemImage: "timer")
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
            if model.timerKind == "duration" {
                HStack(spacing: 8) {
                    TextField(L("Minutes"), value: $model.minutes, format: .number.precision(.fractionLength(0...1)))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                    Text(L("minutes")).foregroundStyle(.secondary)
                    Spacer()
                    ForEach([15.0, 60.0, 240.0], id: \.self) { value in
                        Button(value == 60 ? L("1 h") : value == 240 ? L("4 h") : L("15 m")) {
                            model.minutes = value
                            model.timerChanged()
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.tint)
                    }
                }
                .onSubmit { model.timerChanged() }
            } else if model.timerKind == "until" {
                DatePicker(L("End time"), selection: $model.until, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.field)
            }
            HStack {
                if model.timerKind != "none" {
                    Button(L("Apply timer"), action: model.timerChanged)
                        .controlSize(.small)
                }
                Spacer(minLength: 8)
                if let deadlineText {
                    Text(String(format: L("Ends at %@"), deadlineText))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .cardStyle()
    }

    private var movementBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text(L("Idle delay")).font(.subheadline).frame(width: 108, alignment: .leading)
                secondsField($model.idleThreshold)
                Text(L("seconds")).font(.caption).foregroundStyle(.secondary).fixedSize()
                Spacer(minLength: 0)
            }
            HStack(spacing: 6) {
                Text(L("Move every")).font(.subheadline).frame(width: 108, alignment: .leading)
                secondsField($model.intervalLow)
                Text("–").foregroundStyle(.secondary)
                secondsField($model.intervalHigh)
                Text(L("seconds")).font(.caption).foregroundStyle(.secondary).fixedSize()
                Spacer(minLength: 0)
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
                Spacer(minLength: 8)
            }
        }
        .onSubmit { model.movementChanged() }
    }

    private var shortcutRow: some View {
        HStack(spacing: 8) {
            Label(L("Shortcut"), systemImage: "keyboard")
            Spacer(minLength: 8)
            if model.recordingHotkey {
                Text(L("Press a key combination")).font(.caption).foregroundStyle(.secondary)
                Button(L("Cancel"), action: model.recordHotkey).controlSize(.small)
            } else {
                Text(model.hotkeyDisplay.isEmpty ? "—" : model.hotkeyDisplay)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
                Button(L("Record"), action: model.recordHotkey).controlSize(.small)
            }
        }
    }

    private func secondsField(_ value: Binding<Double>) -> some View {
        TextField("", value: value, format: .number.precision(.fractionLength(0)))
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.trailing)
            .frame(width: 52)
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
        }
        .controlSize(.small)
    }

    private var modeCard: some View {
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
        }
        .cardStyle()
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
            }
            displaySetting
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
            Menu {
                Button(L("Quit"), action: model.quit)
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 24)
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

private extension View {
    func cardStyle() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.quaternary.opacity(0.34), in: RoundedRectangle(cornerRadius: 12))
    }
}
