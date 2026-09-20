import SwiftUI

final class PanelModel: ObservableObject {
    @Published var status = Engine.Status()
    @Published var panelHeight: CGFloat = 560
    @Published var preventDisplaySleep = true
    @Published var mode = "schedule"
    @Published var timerKind = "none"
    @Published var minutes: Double = 15
    @Published var until = Date()
    @Published var login = false
    @Published var idleThreshold: Double = 40
    @Published var intervalLow: Double = 45
    @Published var intervalHigh: Double = 90
    @Published var intervalSummary = ""
    @Published var movementExpanded = true
    @Published var topToken = UUID()
    @Published var error: String?

    var toggle: () -> Void = {}
    var screen: () -> Void = {}
    var modeChanged: (String) -> Void = { _ in }
    var timerChanged: () -> Void = {}
    var movementChanged: () -> Void = {}
    var movementToggled: (Bool) -> Void = { _ in }
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
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        timerCard
                        movementCard
                        displayCard
                        modeCard
                        if let error = model.error {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .font(.footnote)
                                .foregroundStyle(.orange)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if !model.status.accessibilityTrusted { permissionCard }
                            DisclosureGroup {
                                settings
                            } label: {
                                Label(L("Settings"), systemImage: "gearshape")
                                    .font(.headline)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(.quaternary.opacity(0.34), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(14)
                    .id("panel-top")
                }
                .onChange(of: model.topToken) { _, _ in
                    proxy.scrollTo("panel-top", anchor: .top)
                }
            }
            Divider().opacity(0.45)
            footer
        }
        .frame(width: 360, height: model.panelHeight)
        .background(.regularMaterial)
        .preferredColorScheme(nil)
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
                if !model.intervalSummary.isEmpty {
                    Text(model.intervalSummary).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            Toggle("", isOn: Binding(get: { model.status.running }, set: { _ in model.toggle() }))
                .labelsHidden()
                .toggleStyle(.switch)
                .accessibilityLabel(L("GiGi active"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private var statusLabel: String {
        if !model.status.accessibilityTrusted {
            return model.status.displayAssertion ? L("Screen awake · permission pending") : L("Accessibility permission needed")
        }
        if model.status.running && model.status.outOfSchedule { return L("Waiting for schedule") }
        return model.status.running ? L("Active") : L("Inactive")
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

    private var movementCard: some View {
        DisclosureGroup(isExpanded: Binding(get: { model.movementExpanded }, set: {
            model.movementExpanded = $0
            model.movementToggled($0)
        })) {
            VStack(alignment: .leading, spacing: 10) {
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
                HStack {
                    Button(L("Apply movement"), action: model.movementChanged)
                        .controlSize(.small)
                    Spacer(minLength: 8)
                }
            }
            .padding(.top, 10)
            .onSubmit { model.movementChanged() }
        } label: {
            cardTitle(L("Movement"), systemImage: "speedometer")
        }
        .cardStyle()
    }

    private func secondsField(_ value: Binding<Double>) -> some View {
        TextField("", value: value, format: .number.precision(.fractionLength(0)))
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.trailing)
            .frame(width: 52)
    }

    private var displayCard: some View {
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
        .cardStyle()
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

    private var settings: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(L("Start at login"), isOn: Binding(get: { model.login }, set: {
                model.login = $0
                model.loginChanged()
            }))
            Button(L("Reload configuration"), action: model.reload)
            Button(L("Open configuration folder"), action: model.configFolder)
            Button(L("Open log"), action: model.log)
        }
        .font(.subheadline)
        .padding(.top, 9)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: L("%d movements"), model.status.jiggles))
                    .font(.caption.weight(.medium))
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
