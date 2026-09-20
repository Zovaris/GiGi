import Foundation
import Carbon.HIToolbox

struct Hotkey: Equatable {
    struct Key {
        var name: String
        var display: String
        var code: UInt32
    }

    var keyCode: UInt32
    var modifiers: UInt32
    var display: String
    var config: String

    static let keys: [Key] = [
        Key(name: "a", display: "A", code: UInt32(kVK_ANSI_A)),
        Key(name: "b", display: "B", code: UInt32(kVK_ANSI_B)),
        Key(name: "c", display: "C", code: UInt32(kVK_ANSI_C)),
        Key(name: "d", display: "D", code: UInt32(kVK_ANSI_D)),
        Key(name: "e", display: "E", code: UInt32(kVK_ANSI_E)),
        Key(name: "f", display: "F", code: UInt32(kVK_ANSI_F)),
        Key(name: "g", display: "G", code: UInt32(kVK_ANSI_G)),
        Key(name: "h", display: "H", code: UInt32(kVK_ANSI_H)),
        Key(name: "i", display: "I", code: UInt32(kVK_ANSI_I)),
        Key(name: "j", display: "J", code: UInt32(kVK_ANSI_J)),
        Key(name: "k", display: "K", code: UInt32(kVK_ANSI_K)),
        Key(name: "l", display: "L", code: UInt32(kVK_ANSI_L)),
        Key(name: "m", display: "M", code: UInt32(kVK_ANSI_M)),
        Key(name: "n", display: "N", code: UInt32(kVK_ANSI_N)),
        Key(name: "o", display: "O", code: UInt32(kVK_ANSI_O)),
        Key(name: "p", display: "P", code: UInt32(kVK_ANSI_P)),
        Key(name: "q", display: "Q", code: UInt32(kVK_ANSI_Q)),
        Key(name: "r", display: "R", code: UInt32(kVK_ANSI_R)),
        Key(name: "s", display: "S", code: UInt32(kVK_ANSI_S)),
        Key(name: "t", display: "T", code: UInt32(kVK_ANSI_T)),
        Key(name: "u", display: "U", code: UInt32(kVK_ANSI_U)),
        Key(name: "v", display: "V", code: UInt32(kVK_ANSI_V)),
        Key(name: "w", display: "W", code: UInt32(kVK_ANSI_W)),
        Key(name: "x", display: "X", code: UInt32(kVK_ANSI_X)),
        Key(name: "y", display: "Y", code: UInt32(kVK_ANSI_Y)),
        Key(name: "z", display: "Z", code: UInt32(kVK_ANSI_Z)),
        Key(name: "0", display: "0", code: UInt32(kVK_ANSI_0)),
        Key(name: "1", display: "1", code: UInt32(kVK_ANSI_1)),
        Key(name: "2", display: "2", code: UInt32(kVK_ANSI_2)),
        Key(name: "3", display: "3", code: UInt32(kVK_ANSI_3)),
        Key(name: "4", display: "4", code: UInt32(kVK_ANSI_4)),
        Key(name: "5", display: "5", code: UInt32(kVK_ANSI_5)),
        Key(name: "6", display: "6", code: UInt32(kVK_ANSI_6)),
        Key(name: "7", display: "7", code: UInt32(kVK_ANSI_7)),
        Key(name: "8", display: "8", code: UInt32(kVK_ANSI_8)),
        Key(name: "9", display: "9", code: UInt32(kVK_ANSI_9)),
        Key(name: "space", display: "Space", code: UInt32(kVK_Space)),
        Key(name: "tab", display: "⇥", code: UInt32(kVK_Tab)),
        Key(name: "return", display: "↩", code: UInt32(kVK_Return)),
        Key(name: "delete", display: "⌫", code: UInt32(kVK_Delete)),
        Key(name: "left", display: "←", code: UInt32(kVK_LeftArrow)),
        Key(name: "right", display: "→", code: UInt32(kVK_RightArrow)),
        Key(name: "up", display: "↑", code: UInt32(kVK_UpArrow)),
        Key(name: "down", display: "↓", code: UInt32(kVK_DownArrow)),
        Key(name: "f1", display: "F1", code: UInt32(kVK_F1)),
        Key(name: "f2", display: "F2", code: UInt32(kVK_F2)),
        Key(name: "f3", display: "F3", code: UInt32(kVK_F3)),
        Key(name: "f4", display: "F4", code: UInt32(kVK_F4)),
        Key(name: "f5", display: "F5", code: UInt32(kVK_F5)),
        Key(name: "f6", display: "F6", code: UInt32(kVK_F6)),
        Key(name: "f7", display: "F7", code: UInt32(kVK_F7)),
        Key(name: "f8", display: "F8", code: UInt32(kVK_F8)),
        Key(name: "f9", display: "F9", code: UInt32(kVK_F9)),
        Key(name: "f10", display: "F10", code: UInt32(kVK_F10)),
        Key(name: "f11", display: "F11", code: UInt32(kVK_F11)),
        Key(name: "f12", display: "F12", code: UInt32(kVK_F12)),
    ]

    static let disabledName = "none"

    static let `default` = from(keyCode: UInt32(kVK_ANSI_J),
                                modifiers: UInt32(controlKey | cmdKey))
        ?? Hotkey(keyCode: 0, modifiers: 0, display: "", config: disabledName)

    static func from(keyCode: UInt32, modifiers: UInt32) -> Hotkey? {
        guard let key = keys.first(where: { $0.code == keyCode }) else { return nil }
        var display = ""
        var names: [String] = []
        if modifiers & UInt32(controlKey) != 0 { display += "⌃"; names.append("ctrl") }
        if modifiers & UInt32(optionKey) != 0 { display += "⌥"; names.append("opt") }
        if modifiers & UInt32(shiftKey) != 0 { display += "⇧"; names.append("shift") }
        if modifiers & UInt32(cmdKey) != 0 { display += "⌘"; names.append("cmd") }
        names.append(key.name)
        return Hotkey(keyCode: keyCode,
                      modifiers: modifiers,
                      display: display + key.display,
                      config: names.joined(separator: "+"))
    }

    static func parse(_ text: String) -> Hotkey? {
        let tokens = text.lowercased()
            .split(separator: "+")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard let keyName = tokens.last,
              let key = keys.first(where: { $0.name == keyName }) else { return nil }
        var carbon: UInt32 = 0
        for token in tokens.dropLast() {
            switch token {
            case "ctrl", "control": carbon |= UInt32(controlKey)
            case "cmd", "command": carbon |= UInt32(cmdKey)
            case "opt", "option", "alt": carbon |= UInt32(optionKey)
            case "shift": carbon |= UInt32(shiftKey)
            default: return nil
            }
        }
        return from(keyCode: key.code, modifiers: carbon)
    }

    var isDisabled: Bool { config == Hotkey.disabledName || display.isEmpty }
}

final class HotkeyCenter {
    static let shared = HotkeyCenter()
    static let signature: OSType = 0x47494749
    static let identifier: UInt32 = 1

    var onPress: (() -> Void)?
    private(set) var registered: Hotkey?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    @discardableResult
    func register(_ hotkey: Hotkey) -> Bool {
        unregister()
        guard !hotkey.isDisabled else { return true }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        let installStatus = InstallEventHandler(GetEventDispatcherTarget(), { _, event, _ -> OSStatus in
            guard let event else { return OSStatus(eventNotHandledErr) }
            var identifier = EventHotKeyID()
            let status = GetEventParameter(event,
                                           EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID),
                                           nil,
                                           MemoryLayout<EventHotKeyID>.size,
                                           nil,
                                           &identifier)
            guard status == noErr,
                  identifier.signature == HotkeyCenter.signature,
                  identifier.id == HotkeyCenter.identifier else { return OSStatus(eventNotHandledErr) }
            DispatchQueue.main.async { HotkeyCenter.shared.onPress?() }
            return noErr
        }, 1, &eventType, nil, &eventHandler)
        guard installStatus == noErr else {
            Log.error("hotkey: cannot install handler (\(installStatus))")
            return false
        }

        var ref: EventHotKeyRef?
        let identifier = EventHotKeyID(signature: HotkeyCenter.signature, id: HotkeyCenter.identifier)
        let status = RegisterEventHotKey(hotkey.keyCode, hotkey.modifiers, identifier,
                                        GetEventDispatcherTarget(), 0, &ref)
        guard status == noErr, let ref else {
            Log.error("hotkey: cannot register \(hotkey.config) (\(status))")
            unregister()
            return false
        }
        hotKeyRef = ref
        registered = hotkey
        Log.info("hotkey: \(hotkey.config) registered")
        return true
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
        hotKeyRef = nil
        eventHandler = nil
        if let registered { Log.info("hotkey: \(registered.config) released") }
        registered = nil
    }
}
