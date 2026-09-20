import AppKit

enum StatusIcon {
    enum State: CaseIterable {
        case inactive, active, waiting, permissionNeeded

        var label: String {
            switch self {
            case .inactive: return "Inactive"
            case .active: return "Active"
            case .waiting: return "Waiting for schedule"
            case .permissionNeeded: return "Accessibility permission needed"
            }
        }
    }

    static func state(for status: Engine.Status) -> State {
        if !status.accessibilityTrusted { return .permissionNeeded }
        if !status.running { return .inactive }
        return status.outOfSchedule ? .waiting : .active
    }

    private static let images: [State: NSImage] = Dictionary(
        uniqueKeysWithValues: State.allCases.map { ($0, makeImage(for: $0)) }
    )

    static func image(for state: State) -> NSImage {
        images[state]!
    }

    private static func makeImage(for state: State) -> NSImage {
        let mouse = NSImage(systemSymbolName: state == .active ? "computermouse.fill" : "computermouse",
                            accessibilityDescription: nil)
        let image = NSImage(size: NSSize(width: 26, height: 18), flipped: false) { _ in
            mouse?.draw(in: NSRect(x: 1, y: 1, width: 13, height: 16))
            switch state {
            case .inactive:
                break
            case .active:
                NSColor.black.setFill()
                NSBezierPath(ovalIn: NSRect(x: 18, y: 2, width: 5, height: 5)).fill()
            case .waiting:
                NSImage(systemSymbolName: "moon.fill", accessibilityDescription: nil)?
                    .draw(in: NSRect(x: 16, y: 1, width: 9, height: 9))
            case .permissionNeeded:
                NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil)?
                    .draw(in: NSRect(x: 15, y: 1, width: 11, height: 10))
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
