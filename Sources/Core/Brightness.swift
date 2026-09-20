import CoreGraphics
import Foundation

struct Brightness {
    var read: (CGDirectDisplayID) -> Double?
    var write: (CGDirectDisplayID, Double) -> Bool

    static let system = Brightness(
        read: { display in
            guard let get = DisplayServices.getBrightness else { return nil }
            var value: Float = 0
            guard get(display, &value) == 0 else { return nil }
            return Double(value)
        },
        write: { display, value in
            guard let set = DisplayServices.setBrightness else { return false }
            return set(display, Float(min(1, max(0, value)))) == 0
        }
    )

    static let unsupported = Brightness(read: { _ in nil }, write: { _, _ in false })

    var isSupported: Bool { current() != nil }

    func current(_ display: CGDirectDisplayID = CGMainDisplayID()) -> Double? {
        read(display)
    }

    @discardableResult
    func set(_ value: Double, on display: CGDirectDisplayID = CGMainDisplayID()) -> Bool {
        write(display, min(1, max(0, value)))
    }
}

private enum DisplayServices {
    typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    typealias SetBrightness = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private static let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
                                       RTLD_NOW)

    private static func symbol<T>(_ name: String, as type: T.Type) -> T? {
        guard let handle, let pointer = dlsym(handle, name) else { return nil }
        return unsafeBitCast(pointer, to: T.self)
    }

    static let getBrightness = symbol("DisplayServicesGetBrightness", as: GetBrightness.self)
    static let setBrightness = symbol("DisplayServicesSetBrightness", as: SetBrightness.self)
}
