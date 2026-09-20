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

    private static func drawCursor(ink: NSColor, running: Bool) {
        ink.setFill()
        ink.setStroke()
        let cursor = NSBezierPath()
        cursor.move(to: NSPoint(x: 6, y: 12))
        cursor.curve(to: NSPoint(x: 7.6, y: 13), controlPoint1: NSPoint(x: 5.8, y: 13.3),
                     controlPoint2: NSPoint(x: 6.7, y: 13.7))
        cursor.line(to: NSPoint(x: 17.5, y: 6))
        cursor.curve(to: NSPoint(x: 17, y: 4.4), controlPoint1: NSPoint(x: 18.5, y: 5.3),
                     controlPoint2: NSPoint(x: 18.1, y: 4.6))
        cursor.line(to: NSPoint(x: 12.5, y: 3.8))
        cursor.line(to: NSPoint(x: 9.5, y: 0.7))
        cursor.curve(to: NSPoint(x: 7.8, y: 1.2), controlPoint1: NSPoint(x: 8.7, y: -0.1),
                     controlPoint2: NSPoint(x: 8, y: 0.2))
        cursor.close()
        if running {
            cursor.fill()
        } else {
            cursor.lineWidth = 1.5
            cursor.lineJoinStyle = .round
            cursor.stroke()
        }
        guard running else { return }

        let rays = NSBezierPath()
        rays.lineWidth = 1.7
        rays.lineCapStyle = .round
        for (start, end) in [
            (NSPoint(x: 2, y: 11.8), NSPoint(x: 3.4, y: 11.8)),
            (NSPoint(x: 3.2, y: 17), NSPoint(x: 4.4, y: 15.6)),
            (NSPoint(x: 8, y: 19), NSPoint(x: 8, y: 17.4))
        ] {
            rays.move(to: start)
            rays.line(to: end)
        }
        rays.stroke()
    }

    static func image(for state: State, appearance: NSAppearance? = nil, running: Bool? = nil) -> NSImage {
        let dark = appearance?.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let ink = dark ? NSColor.white : NSColor.black
        let image = NSImage(size: NSSize(width: 22, height: 20), flipped: false) { _ in
            drawCursor(ink: ink, running: running ?? (state != .inactive))
            if state != .inactive {
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current?.compositingOperation = .copy
                NSColor.clear.setFill()
                NSBezierPath(ovalIn: NSRect(x: 10, y: 9, width: 12, height: 12)).fill()
                NSGraphicsContext.restoreGraphicsState()
                let badge = NSRect(x: 11.5, y: 10.5, width: 9, height: 9)
                switch state {
                case .active: NSColor.systemGreen.setFill()
                case .waiting: NSColor.systemOrange.setFill()
                case .permissionNeeded: NSColor.systemRed.setFill()
                case .inactive: break
                }
                NSBezierPath(ovalIn: badge).fill()
                if state == .permissionNeeded {
                    let mark = "!" as NSString
                    mark.draw(at: NSPoint(x: 14.5, y: 10.7), withAttributes: [
                        .font: NSFont.systemFont(ofSize: 8, weight: .heavy),
                        .foregroundColor: NSColor.white
                    ])
                }
            }
            return true
        }
        image.isTemplate = false
        return image
    }
}
