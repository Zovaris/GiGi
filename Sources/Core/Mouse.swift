import Foundation
import CoreGraphics
import ApplicationServices

let trackedEventTypes: [CGEventType] = [
    .mouseMoved, .leftMouseDown, .leftMouseDragged, .rightMouseDown,
    .rightMouseDragged, .otherMouseDown, .otherMouseDragged,
    .scrollWheel, .keyDown, .keyUp, .flagsChanged,
]

func userIdleSeconds() -> Double {
    var best = Double.greatestFiniteMagnitude
    for type in trackedEventTypes {
        let seconds = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: type)
        if seconds >= 0 && seconds < best { best = seconds }
    }
    return best == .greatestFiniteMagnitude ? 0 : best
}

func hidIdleSeconds() -> Double? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
    process.arguments = ["-c", "IOHIDSystem", "-r", "-d", "1"]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()
    do { try process.run() } catch { return nil }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard let text = String(data: data, encoding: .utf8) else { return nil }
    for line in text.split(separator: "\n") where line.contains("HIDIdleTime") {
        let value = line.split(separator: "=").last?
            .trimmingCharacters(in: CharacterSet(charactersIn: " \"\t")) ?? ""
        if let nanoseconds = UInt64(value) { return Double(nanoseconds) / 1_000_000_000.0 }
    }
    return nil
}

func accessibilityTrusted() -> Bool {
    AXIsProcessTrusted()
}

func requestAccessibility(prompt: Bool) {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(options)
}

func openAccessibilitySettings() {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = ["x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"]
    try? process.run()
}

func activeDisplayBounds(containing point: CGPoint) -> CGRect? {
    var count: UInt32 = 0
    CGGetActiveDisplayList(0, nil, &count)
    guard count > 0 else { return nil }
    var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
    var actual: UInt32 = 0
    CGGetActiveDisplayList(count, &ids, &actual)
    for id in ids {
        let bounds = CGDisplayBounds(id)
        if bounds.contains(point) { return bounds }
    }
    return nil
}

func postMouseMove(to point: CGPoint, source: CGEventSource?) {
    guard let event = CGEvent(mouseEventSource: source,
                              mouseType: .mouseMoved,
                              mouseCursorPosition: point,
                              mouseButton: .left) else { return }
    event.post(tap: .cghidEventTap)
}

@discardableResult
func jiggle(distance: Double, stateID: CGEventSourceStateID?) -> Bool {
    guard let current = CGEvent(source: nil)?.location else {
        Log.error("jiggle: cannot read cursor position")
        return false
    }
    var dx = distance
    if let bounds = activeDisplayBounds(containing: current) {
        let margin = 4.0
        if current.x + dx > bounds.maxX - margin || current.x + dx < bounds.minX + margin {
            dx = -dx
        }
    }
    let source = stateID.flatMap { CGEventSource(stateID: $0) }
    postMouseMove(to: CGPoint(x: current.x + dx, y: current.y), source: source)
    usleep(60_000)
    postMouseMove(to: current, source: source)
    return true
}
