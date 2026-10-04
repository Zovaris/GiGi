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

    static let size = NSSize(width: 20, height: 18)
    private static let scale: CGFloat = 0.049
    private static let outline: [(x: CGFloat, y: CGFloat, radius: CGFloat)] = [
        (0, 0, 1.3), (194, 124, 1.0), (102, 150, 0.5), (40, 210, 1.0)
    ]

    static func state(for status: Engine.Status) -> State {
        if !status.accessibilityTrusted { return .permissionNeeded }
        if !status.running { return .inactive }
        return (status.outOfSchedule || status.waitingForApp) ? .waiting : .active
    }

    private static var tip: NSPoint {
        let points = outline.map { NSPoint(x: $0.x * scale, y: $0.y * scale) }
        let box = NSRect(x: 0, y: 0, width: points.map(\.x).max() ?? 0, height: points.map(\.y).max() ?? 0)
        let centroid = NSPoint(x: points.map(\.x).reduce(0, +) / CGFloat(points.count),
                               y: points.map(\.y).reduce(0, +) / CGFloat(points.count))
        let optical = NSPoint(x: (box.midX + centroid.x) / 2, y: (box.midY + centroid.y) / 2)
        return NSPoint(x: size.width / 2 - optical.x, y: size.height / 2 + optical.y)
    }

    private static func pointer() -> NSBezierPath {
        let origin = tip
        let corners = outline.map { CGPoint(x: origin.x + $0.x * scale, y: origin.y - $0.y * scale) }
        let path = CGMutablePath()
        let last = corners[corners.count - 1]
        path.move(to: CGPoint(x: (last.x + corners[0].x) / 2, y: (last.y + corners[0].y) / 2))
        for (index, corner) in corners.enumerated() {
            path.addArc(tangent1End: corner, tangent2End: corners[(index + 1) % corners.count],
                        radius: outline[index].radius)
        }
        path.closeSubpath()
        return NSBezierPath(cgPath: path)
    }

    private static func rays() -> NSBezierPath {
        let origin = NSPoint(x: tip.x + 0.7, y: tip.y - 0.8)
        let path = NSBezierPath()
        path.lineWidth = 1.4
        path.lineCapStyle = .round
        for degrees in [78.0, 130.0, 186.0] {
            let angle = degrees * .pi / 180
            let direction = NSPoint(x: cos(angle), y: sin(angle))
            path.move(to: NSPoint(x: origin.x + direction.x * 1.7, y: origin.y + direction.y * 1.7))
            path.line(to: NSPoint(x: origin.x + direction.x * 3.5, y: origin.y + direction.y * 3.5))
        }
        return path
    }

    private static let badgeRect = NSRect(x: size.width - 8, y: size.height - 8, width: 8, height: 8)

    private static func drawBadge(_ name: String, palette: [NSColor]? = nil) {
        var configuration = NSImage.SymbolConfiguration(pointSize: 8, weight: .bold)
        if let palette { configuration = configuration.applying(.init(paletteColors: palette)) }
        guard let badge = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration) else { return }
        badge.draw(at: NSPoint(x: badgeRect.midX - badge.size.width / 2, y: badgeRect.midY - badge.size.height / 2),
                   from: .zero, operation: .sourceOver, fraction: 1)
    }

    private static func clearBadgeArea() {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.compositingOperation = .clear
        NSBezierPath(ovalIn: badgeRect.insetBy(dx: -1.3, dy: -1.3)).fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    static func image(for state: State) -> NSImage {
        let image = NSImage(size: size, flipped: false) { _ in
            NSColor.black.set()
            let shape = pointer()
            if state == .inactive {
                shape.lineWidth = 1.3
                shape.lineJoinStyle = .round
                shape.stroke()
            } else {
                shape.fill()
            }
            if state == .active { rays().stroke() }
            if state == .waiting || state == .permissionNeeded { clearBadgeArea() }
            if state == .waiting { drawBadge("pause.circle.fill") }
            return true
        }
        image.isTemplate = true
        return image
    }

    static func badge(for state: State) -> NSImage {
        NSImage(size: size, flipped: false) { _ in
            if state == .permissionNeeded { drawBadge("exclamationmark.circle.fill", palette: [.white, .systemRed]) }
            return true
        }
    }
}

final class StatusBadgeView: NSImageView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
