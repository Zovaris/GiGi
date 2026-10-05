import Foundation
import CoreGraphics

enum MotionTests {
    static func run() {
        let radius = 40.0

        for pattern in Motion.patterns {
            let path = Motion.offsets(pattern: pattern, radius: radius)
            assert(!path.isEmpty, "\(pattern) must produce a path")
            if Motion.returnsHome(pattern) {
                assert(path.last == .zero, "\(pattern) must bring the cursor back to where it started")
            } else {
                assert(path.last != .zero, "\(pattern) must leave the cursor somewhere new")
                assert(hypot(path.last!.x, path.last!.y) > 0.5, "\(pattern) must not land back on the start")
            }
            let reach = path.map { hypot($0.x, $0.y) }.max() ?? 0
            assert(reach > 0.5, "\(pattern) must actually move the cursor")
            assert(reach <= radius * 1.5, "\(pattern) must stay near its radius, got \(reach)")
            assert(path.count >= 2, "\(pattern) needs at least a departure and a return")
        }

        assert(Motion.returnsHome("random") == false, "the random walk ends somewhere new")
        assert(Motion.returnsHome("circle"), "shapes come back home")
        assert(Motion.returnsHome("zigzag"), "an unknown pattern behaves like the jiggle and comes home")

        assert(Motion.offsets(pattern: Motion.defaultPattern, radius: 7) == [CGPoint(x: 7, y: 0), .zero],
               "the jiggle nudge is a fixed offset and back")

        let circle = Motion.circlePoints(radius: radius)
        for point in circle {
            assert(abs(hypot(point.x, point.y) - radius) < 0.001, "every circle point sits on the radius")
        }
        assert(circle.contains { $0.y >= radius } && circle.contains { $0.y <= -radius },
               "the circle reaches top and bottom")
        assert(circle.first == circle.last, "the circle closes on itself")

        let square = Motion.squarePoints(radius: radius)
        assert(square.contains(CGPoint(x: radius, y: radius)), "the square has a corner")
        assert(square.contains(CGPoint(x: -radius, y: -radius)), "the square has the opposite corner")
        assert(square.first == CGPoint(x: 0, y: radius), "the square starts above the cursor")
        assert(square.allSatisfy { abs(abs($0.x) - radius) < 0.001 || abs(abs($0.y) - radius) < 0.001 },
               "every square point lies on an edge")

        let triangle = Motion.trianglePoints(radius: radius)
        assert(triangle.first!.x == 0 && triangle.first!.y == radius,
               "the triangle starts above the cursor")
        let corners = Set(triangle.map { "\(Int(round($0.x))),\(Int(round($0.y)))" })
        assert(corners.contains("0,40") && corners.contains("35,-20") && corners.contains("-35,-20"),
               "the triangle has three corners at the radius")
        assert(triangle.allSatisfy { hypot($0.x, $0.y) <= radius + 0.001 },
               "the triangle stays inside its radius")

        let star = Motion.starPoints(radius: radius)
        let starReach = star.map { hypot($0.x, $0.y) }
        assert(abs(starReach.max()! - radius) < 0.001, "the star has spikes at the radius")
        assert(starReach.min()! < radius * 0.5, "the star has points pulled inwards")
        assert(star.contains { abs($0.x) < 0.001 && $0.y > radius * 0.99 }, "the star points up first")

        let spiral = Motion.spiralPoints(radius: radius)
        assert(spiral.first == .zero && spiral.last == .zero, "the spiral leaves and returns to the centre")
        assert(abs(spiral.map { hypot($0.x, $0.y) }.max()! - radius) < 0.001, "the spiral reaches its radius")

        var randomEnds = Set<String>()
        for _ in 0..<20 {
            let path = Motion.offsets(pattern: "random", radius: radius)
            let end = path.last!
            assert(end != .zero, "the random walk never ends on the starting point")
            assert(hypot(end.x, end.y) >= radius * 0.6 - 0.001,
                   "the random walk lands a clear distance from the start")
            assert(path.map { hypot($0.x, $0.y) }.max()! <= radius + 0.001,
                   "the random walk stays inside its radius")
            randomEnds.insert("\(Int(round(end.x))),\(Int(round(end.y)))")
        }
        assert(randomEnds.count > 1, "the random walk is not the same every time")

        let eight = Motion.figureEightPoints(radius: radius)
        assert(eight.first == .zero && eight.last == .zero, "the figure eight starts and ends at the cursor")
        assert(eight.contains { $0.x >= radius } && eight.contains { $0.x <= -radius },
               "the figure eight spans left and right")
        assert(eight.allSatisfy { abs($0.y) <= radius / 2 + 0.001 }, "the figure eight is half as tall as it is wide")

        let drawn = Motion.offsets(pattern: "circle", radius: radius)
        assert(drawn.contains(circle.first!), "the drawn circle reaches its own edge")
        assert(drawn.first != circle.first, "the cursor glides into the shape instead of jumping to it")

        assert(Motion.offsets(pattern: "zigzag", radius: radius) == Motion.offsets(pattern: "jiggle", radius: radius),
               "an unknown pattern falls back to the jiggle")
        assert(Motion.offsets(pattern: "circle", radius: 0).map { hypot($0.x, $0.y) }.max()! <= 2,
               "a radius below the floor is clamped up, not down to nothing")
        assert(Motion.offsets(pattern: "circle", radius: 10_000).map { hypot($0.x, $0.y) }.max()! <= 300,
               "an absurd radius is clamped to the ceiling")
        assert(Motion.offsets(pattern: "circle", radius: .nan)
               == Motion.offsets(pattern: "circle", radius: Motion.defaultRadiusPixels),
               "a broken radius falls back to the default")

        assert(Motion.clampRadius(1) == 2 && Motion.clampRadius(299.6) == 300, "the radius is clamped to 2...300")
        assert(Motion.clampRadius(.infinity) == Motion.defaultRadiusPixels, "an infinite radius is refused")

        let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        assert(clampToDisplay(CGPoint(x: 500, y: -20), bounds: bounds) == CGPoint(x: 98, y: 2),
               "a point outside the display is pulled back inside")

        var config = Config.default
        assert(config.motionPattern == "jiggle", "the default pattern is the jiggle")
        assert(config.motionRadiusPixels == 40, "the default radius is 40px")

        let legacy = try! JSONDecoder().decode(Config.self, from: Data("{}".utf8))
        assert(legacy.motionPattern == "jiggle" && legacy.motionRadiusPixels == 40,
               "a config written before the patterns still decodes")

        config.motionPattern = "zigzag"
        config.motionRadiusPixels = 9000
        let fixed = config.sanitized()
        assert(fixed.motionPattern == "jiggle", "an unknown pattern is dropped")
        assert(fixed.motionRadiusPixels == 300, "the radius is clamped when loading")

        config.motionPattern = "square"
        config.motionRadiusPixels = 40
        let roundTrip = try! JSONDecoder().decode(Config.self, from: try! JSONEncoder().encode(config.sanitized()))
        assert(roundTrip.motionPattern == "square" && roundTrip.motionRadiusPixels == 40,
               "the pattern and the radius survive a save")

        for pattern in Motion.patterns {
            assert(!Motion.label(pattern).isEmpty, "\(pattern) must have a label to show in the panel")
        }

        print("Motion checks passed")
    }
}
