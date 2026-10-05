import Foundation
import CoreGraphics

enum Motion {
    static let patterns = ["jiggle", "circle", "square", "figureEight", "triangle", "star", "spiral", "random"]
    static let defaultPattern = "jiggle"
    static let randomPattern = "random"
    static let defaultRadiusPixels: Double = 40
    static let radiusRange: ClosedRange<Double> = 2...300
    static let defaultJiggleDistancePixels: Double = 2
    static let distanceRange: ClosedRange<Double> = 0...300
    static let stepDelayMicroseconds: UInt32 = 8_000
    static let glideSteps = 6

    static let wanderingPatterns = [defaultPattern, randomPattern]

    static func returnsHome(_ pattern: String) -> Bool {
        guard patterns.contains(pattern) else { return false }
        return !wanderingPatterns.contains(pattern)
    }

    static func clampRadius(_ radius: Double) -> Double {
        guard radius.isFinite else { return defaultRadiusPixels }
        return min(radiusRange.upperBound, max(radiusRange.lowerBound, radius.rounded()))
    }

    static func clampDistance(_ distance: Double) -> Double {
        guard distance.isFinite else { return defaultJiggleDistancePixels }
        return min(distanceRange.upperBound, max(distanceRange.lowerBound, distance.rounded()))
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
        default: return jiggleOffsets(distance: size)
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

    private static func glide(from start: CGPoint, to end: CGPoint, steps: Int = glideSteps) -> [CGPoint] {
        guard steps > 0, hypot(end.x - start.x, end.y - start.y) > 0.5 else { return [] }
        return (1...steps).map { step in
            let progress = Double(step) / Double(steps)
            return CGPoint(x: start.x + (end.x - start.x) * progress,
                           y: start.y + (end.y - start.y) * progress)
        }
    }

    private static func bowedGlide(from start: CGPoint, to end: CGPoint, bow: Double, inside limit: Double) -> [CGPoint] {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = hypot(dx, dy)
        guard length > 0.5 else { return [] }
        let steps = Int.random(in: 3...9)
        let normal = CGPoint(x: -dy / length, y: dx / length)
        return (1...steps).map { step in
            let progress = Double(step) / Double(steps)
            let bulge = sin(Double.pi * progress) * bow
            return within(limit, CGPoint(x: start.x + dx * progress + normal.x * bulge,
                                         y: start.y + dy * progress + normal.y * bulge))
        }
    }

    private static func within(_ limit: Double, _ location: CGPoint) -> CGPoint {
        let distance = hypot(location.x, location.y)
        guard distance > limit, distance > 0 else { return location }
        return CGPoint(x: location.x / distance * limit, y: location.y / distance * limit)
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

    static func jiggleOffsets(distance: Double) -> [CGPoint] {
        guard distance.isFinite, distance > 0 else { return [.zero] }
        let angle = Double.random(in: 0..<(2 * Double.pi))
        let reach = Double.random(in: (distance * 0.6)...distance)
        let target = point(reach * cos(angle), reach * sin(angle))
        let bow = Double.random(in: -1...1) * distance * 0.3
        let path = bowedGlide(from: .zero, to: target, bow: bow, inside: distance)
        return path.isEmpty ? [target] : path
    }

    static func randomOffsets(radius: Double) -> [CGPoint] {
        let stops = Int.random(in: 6...10)
        var path: [CGPoint] = []
        var current = CGPoint.zero
        for index in 0..<stops {
            let angle = Double.random(in: 0..<(2 * Double.pi))
            let reach = index == stops - 1
                ? Double.random(in: (radius * 0.6)...radius)
                : Double.random(in: (radius * 0.2)...radius)
            let next = point(reach * cos(angle), reach * sin(angle))
            path += bowedGlide(from: current, to: next,
                               bow: Double.random(in: -1...1) * radius * 0.3, inside: radius)
            current = next
        }
        if path.last != current { path.append(current) }
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
    let source = stateID.flatMap { CGEventSource(stateID: $0) }
    guard postWalk(Motion.offsets(pattern: pattern, radius: radius), from: start, stateID: stateID) else {
        return false
    }
    if Motion.returnsHome(pattern) { postMouseMove(to: start, source: source) }
    return true
}

@discardableResult
func simulateMotion(pattern: String, distance: Double, radius: Double, stateID: CGEventSourceStateID?) -> Bool {
    if !Motion.patterns.contains(pattern) || pattern == Motion.defaultPattern {
        return jiggle(distance: distance, stateID: stateID)
    }
    return drawMotion(pattern: pattern, radius: radius, stateID: stateID)
}
