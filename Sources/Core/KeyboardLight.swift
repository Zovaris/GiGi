import CoreGraphics
import Foundation

struct KeyboardLight {
    var identifiers: () -> [UInt64]
    var read: (UInt64) -> Double?
    var write: (UInt64, Double) -> Bool

    static let system = KeyboardLight(
        identifiers: { KeyboardBacklightClient.shared?.identifiers ?? [] },
        read: { keyboard in KeyboardBacklightClient.shared?.level(of: keyboard) },
        write: { keyboard, value in KeyboardBacklightClient.shared?.set(value, on: keyboard) ?? false }
    )

    static let unsupported = KeyboardLight(identifiers: { [] }, read: { _ in nil }, write: { _, _ in false })

    var isSupported: Bool { current() != nil }

    func current() -> Double? {
        for keyboard in identifiers() {
            if let level = read(keyboard) { return level }
        }
        return nil
    }

    @discardableResult
    func set(_ value: Double) -> Bool {
        let level = min(1, max(0, value))
        var applied = false
        for keyboard in identifiers() where write(keyboard, level) {
            applied = true
        }
        return applied
    }
}

private final class KeyboardBacklightClient {
    private typealias AllocFn = @convention(c) (AnyClass, Selector) -> Unmanaged<NSObject>
    private typealias InitFn = @convention(c) (NSObject, Selector) -> Unmanaged<NSObject>
    private typealias IdentifiersFn = @convention(c) (NSObject, Selector) -> Unmanaged<NSArray>?
    private typealias ReadFn = @convention(c) (NSObject, Selector, UInt64) -> Float
    private typealias WriteFn = @convention(c) (NSObject, Selector, Float, UInt64) -> Bool

    private static let className = "KeyboardBrightnessClient"
    private static let identifiersSelector = NSSelectorFromString("copyKeyboardBacklightIDs")
    private static let readSelector = NSSelectorFromString("brightnessForKeyboard:")
    private static let writeSelector = NSSelectorFromString("setBrightness:forKeyboard:")

    private static let framework = dlopen(
        "/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness", RTLD_NOW
    )
    private static let runtime = dlopen("/usr/lib/libobjc.A.dylib", RTLD_NOW)

    static let shared: KeyboardBacklightClient? = KeyboardBacklightClient()

    private let client: NSObject
    private let copyIdentifiers: IdentifiersFn
    private let readLevel: ReadFn
    private let writeLevel: WriteFn

    private init?() {
        guard Self.framework != nil,
              let runtime = Self.runtime,
              let classObject = NSClassFromString(Self.className),
              let messageSend = dlsym(runtime, "objc_msgSend") else { return nil }

        let alloc = unsafeBitCast(messageSend, to: AllocFn.self)
        let initMethod = unsafeBitCast(messageSend, to: InitFn.self)
        let identifiers = unsafeBitCast(messageSend, to: IdentifiersFn.self)
        let read = unsafeBitCast(messageSend, to: ReadFn.self)
        let write = unsafeBitCast(messageSend, to: WriteFn.self)
        let responds = unsafeBitCast(messageSend, to: (@convention(c) (NSObject, Selector, Selector) -> Bool).self)

        let instance = initMethod(alloc(classObject, NSSelectorFromString("alloc")).takeUnretainedValue(),
                                  NSSelectorFromString("init")).takeUnretainedValue()
        for selector in [Self.identifiersSelector, Self.readSelector, Self.writeSelector] {
            guard responds(instance, NSSelectorFromString("respondsToSelector:"), selector) else { return nil }
        }

        client = instance
        copyIdentifiers = identifiers
        readLevel = read
        writeLevel = write
    }

    var identifiers: [UInt64] {
        guard let values = copyIdentifiers(client, Self.identifiersSelector)?.takeRetainedValue() as? [NSNumber] else {
            return []
        }
        return values.map { $0.uint64Value }
    }

    func level(of keyboard: UInt64) -> Double? {
        guard identifiers.contains(keyboard) else { return nil }
        return Double(readLevel(client, Self.readSelector, keyboard))
    }

    func set(_ value: Double, on keyboard: UInt64) -> Bool {
        writeLevel(client, Self.writeSelector, Float(min(1, max(0, value))), keyboard)
    }
}
