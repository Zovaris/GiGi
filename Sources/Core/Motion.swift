import Foundation
import CoreGraphics

enum Motion {
    static let patterns = ["jiggle", "circle", "square", "figureEight"]
    static let defaultPattern = "jiggle"
    static let defaultRadiusPixels: Double = 40
    static let radiusRange: ClosedRange<Double> = 2...300
    static let stepDelayMicroseconds: UInt32 = 8_000
    static let glideSteps = 6

    static func clampRadius(_ radius: Double) -> Double {
        guard radius.isFinite else { return defaultRadiusPixels }
        return min(radiusRange.upperBound, max(radiusRange.lowerBound, radius.rounded()))
    }

    static func label(_ pattern: String) -> String {
        switch pattern {
        case "circle": return L("Circle")
        case "square": return L("Square")
        case "figureEight": return L("Figure eight")
        default: return L("Jiggle")
        }
    }

    static func offsets(pattern: String, radius: Double) -> [CGPoint] {
        let size = clampRadius(radius)
        switch pattern {
        case "circle": return closed(circlePoints(radius: size))
        case "square": return closed(squarePoints(radius: size))
        case "figureEight": return figureEightPoints(radius: size)
        default: return [CGPoint(x: size, y: 0), .zero]
        }
    }

    private static func closed(_ shape: [CGPoint]) -> [CGPoint] {
        guard let first = shape.first else { return [.zero] }
        let walked = Array(shape.dropFirst().dropLast())
        return glide(from: .zero, to: first) + walked + glide(from: walked.last ?? first, to: .zero)
    }

    private static func point(_ x: Double, _ y: Double) -> CGPoint {
        CGPoint(x: abs(x) < 1e-9 ? 0 : x, y: abs(y) < 1e-9 ? 0 : y)
    }

    private static func glide(from start: CGPoint, to end: CGPoint) -> [CGPoint] {
        guard hypot(end.x - start.x, end.y - start.y) > 0.5 else { return [] }
        return (1...glideSteps).map { step in
            let progress = Double(step) / Double(glideSteps)
            return CGPoint(x: start.x + (end.x - start.x) * progress,
                           y: start.y + (end.y - start.y) * progress)
        }
    }

    static func circlePoints(radius: Double) -> [CGPoint] {
        let steps = 36
        return (0...steps).map { step in
            let angle = 2 * Double.pi * Double(step) / Double(steps)
            return point(radius * cos(angle), radius * sin(angle))
        }
    }

    static func squarePoints(radius: Double) -> [CGPoint] {
        let corners = [
            CGPoint(x: 0, y: radius),
            CGPoint(x: radius, y: radius),
            CGPoint(x: radius, y: -radius),
            CGPoint(x: -radius, y: -radius),
            CGPoint(x: -radius, y: radius),
        ]
        let perEdge = 8
        var points = [corners[0]]
        for index in 0..<corners.count {
            let from = corners[index]
            let to = corners[(index + 1) % corners.count]
            points += (1...perEdge).map { step in
                let progress = Double(step) / Double(perEdge)
                return CGPoint(x: from.x + (to.x - from.x) * progress,
                               y: from.y + (to.y - from.y) * progress)
            }
        }
        return points
    }

    static func figureEightPoints(radius: Double) -> [CGPoint] {
        let steps = 48
        return (0...steps).map { step in
            let angle = 2 * Double.pi * Double(step) / Double(steps)
            return point(radius * sin(angle), radius / 2 * sin(2 * angle))
        }
    }
}

func clampToDisplay(_ point: CGPoint, bounds: CGRect) -> CGPoint {
    let margin = 2.0
    return CGPoint(x: min(max(point.x, bounds.minX + margin), bounds.maxX - margin),
                   y: min(max(point.y, bounds.minY + margin), bounds.maxY - margin))
}

@discardableResult
func drawMotion(pattern: String, radius: Double, stateID: CGEventSourceStateID?) -> Bool {
    guard let start = CGEvent(source: nil)?.location else {
        Log.error("motion: cannot read cursor position")
        return false
    }
    let bounds = activeDisplayBounds(containing: start)
    let source = stateID.flatMap { CGEventSource(stateID: $0) }
    for offset in Motion.offsets(pattern: pattern, radius: radius) {
        var point = CGPoint(x: start.x + offset.x, y: start.y + offset.y)
        if let bounds { point = clampToDisplay(point, bounds: bounds) }
        postMouseMove(to: point, source: source)
        usleep(Motion.stepDelayMicroseconds)
    }
    postMouseMove(to: start, source: source)
    return true
}

@discardableResult
func simulateMotion(pattern: String, distance: Double, radius: Double, stateID: CGEventSourceStateID?) -> Bool {
    if !Motion.patterns.contains(pattern) || pattern == Motion.defaultPattern {
        return jiggle(distance: distance, stateID: stateID)
    }
    return drawMotion(pattern: pattern, radius: radius, stateID: stateID)
}
