import Foundation
import CoreGraphics

enum Motion {
    static let patterns = ["jiggle", "circle", "square", "figureEight", "triangle", "star", "spiral", "random"]
    static let defaultPattern = "jiggle"
    static let randomPattern = "random"
    static let defaultRadiusPixels: Double = 40
    static let radiusRange: ClosedRange<Double> = 2...300
    static let stepDelayMicroseconds: UInt32 = 8_000
    static let glideSteps = 6

    static func returnsHome(_ pattern: String) -> Bool {
        patterns.contains(pattern) ? pattern != randomPattern : true
    }

    static func clampRadius(_ radius: Double) -> Double {
        guard radius.isFinite else { return defaultRadiusPixels }
        return min(radiusRange.upperBound, max(radiusRange.lowerBound, radius.rounded()))
    }

    static func label(_ pattern: String) -> String {
        switch pattern {
        case "circle": return L("Circle")
        case "square": return L("Square")
        case "figureEight": return L("Figure eight")
        case "triangle": return L("Triangle")
        case "star": return L("Star")
        case "spiral": return L("Spiral")
        case "random": return L("Random")
        default: return L("Jiggle")
        }
    }

    static func offsets(pattern: String, radius: Double) -> [CGPoint] {
        let size = clampRadius(radius)
        switch pattern {
        case "circle": return closed(circlePoints(radius: size))
        case "square": return closed(squarePoints(radius: size))
        case "figureEight": return figureEightPoints(radius: size)
        case "triangle": return closed(trianglePoints(radius: size))
        case "star": return closed(starPoints(radius: size))
        case "spiral": return closed(spiralPoints(radius: size))
        case "random": return randomOffsets(radius: size)
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

    private static func polygon(_ corners: [CGPoint], perEdge: Int) -> [CGPoint] {
        guard corners.count >= 3 else { return corners }
        var points = [corners[0]]
        for index in corners.indices {
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

    static func squarePoints(radius: Double) -> [CGPoint] {
        let corners = [
            CGPoint(x: 0, y: radius),
            CGPoint(x: radius, y: radius),
            CGPoint(x: radius, y: -radius),
            CGPoint(x: -radius, y: -radius),
            CGPoint(x: -radius, y: radius),
        ]
        return polygon(corners, perEdge: 8)
    }

    static func trianglePoints(radius: Double) -> [CGPoint] {
        let corners = (0..<3).map { index -> CGPoint in
            let angle = Double.pi / 2 + 2 * Double.pi * Double(index) / 3
            return point(radius * cos(angle), radius * sin(angle))
        }
        return polygon(corners, perEdge: 10)
    }

    static func starPoints(radius: Double) -> [CGPoint] {
        let spikes = 5
        let inner = radius * 0.4
        let corners = (0..<(spikes * 2)).map { index -> CGPoint in
            let reach = index.isMultiple(of: 2) ? radius : inner
            let angle = Double.pi / 2 + Double.pi * Double(index) / Double(spikes)
            return point(reach * cos(angle), reach * sin(angle))
        }
        return polygon(corners, perEdge: 4)
    }

    static func spiralPoints(radius: Double) -> [CGPoint] {
        let steps = 72
        let turns = 2.0
        return (0...steps).map { step in
            let progress = Double(step) / Double(steps)
            let angle = 2 * Double.pi * turns * progress
            let reach = radius * sin(Double.pi * progress)
            return point(reach * cos(angle), reach * sin(angle))
        }
    }

    static func figureEightPoints(radius: Double) -> [CGPoint] {
        let steps = 48
        return (0...steps).map { step in
            let angle = 2 * Double.pi * Double(step) / Double(steps)
            return point(radius * sin(angle), radius / 2 * sin(2 * angle))
        }
    }

    static func randomOffsets(radius: Double) -> [CGPoint] {
        let stops = 3
        var path: [CGPoint] = []
        var current = CGPoint.zero
        var target = CGPoint(x: radius, y: 0)
        for index in 0..<stops {
            let angle = Double.random(in: 0..<(2 * Double.pi))
            let reach = Double.random(in: (index == stops - 1 ? radius * 0.6 : radius * 0.3)...radius)
            let next = point(reach * cos(angle), reach * sin(angle))
            path += glide(from: current, to: next)
            current = next
            target = next
        }
        if path.last != target { path.append(target) }
        return path
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
