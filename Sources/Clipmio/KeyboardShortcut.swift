// Copyright (c) 2026 tonngyou. MIT License.
import AppKit
import Carbon.HIToolbox

struct KeyboardShortcut: Codable, Equatable, Sendable {
    let keyCode: UInt32
    let modifiers: UInt32

    static let `default` = KeyboardShortcut(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey | shiftKey))
    static let allowedModifiers = UInt32(cmdKey | controlKey | optionKey | shiftKey)

    var isValid: Bool {
        modifiers & UInt32(cmdKey | controlKey) != 0
            && modifiers & ~Self.allowedModifiers == 0 && Self.keyNames[keyCode] != nil
    }

    var label: String {
        var result = ""
        for (flag, symbol) in [(cmdKey, "⌘"), (controlKey, "⌃"), (optionKey, "⌥"), (shiftKey, "⇧")] {
            if modifiers & UInt32(flag) != 0 { result += symbol }
        }
        return result + (Self.keyNames[keyCode] ?? "?")
    }

    init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    init(event: NSEvent) {
        keyCode = UInt32(event.keyCode)
        var flags: UInt32 = 0
        if event.modifierFlags.contains(.command) { flags |= UInt32(cmdKey) }
        if event.modifierFlags.contains(.control) { flags |= UInt32(controlKey) }
        if event.modifierFlags.contains(.option) { flags |= UInt32(optionKey) }
        if event.modifierFlags.contains(.shift) { flags |= UInt32(shiftKey) }
        modifiers = flags
    }

    // Physical key labels remain predictable with Chinese input methods active.
    private static let keyNames: [UInt32: String] = [
        0:"A", 1:"S", 2:"D", 3:"F", 4:"H", 5:"G", 6:"Z", 7:"X", 8:"C", 9:"V",
        11:"B", 12:"Q", 13:"W", 14:"E", 15:"R", 16:"Y", 17:"T", 18:"1", 19:"2",
        20:"3", 21:"4", 22:"6", 23:"5", 24:"=", 25:"9", 26:"7", 27:"-", 28:"8",
        29:"0", 30:"]", 31:"O", 32:"U", 33:"[", 34:"I", 35:"P", 36:"↩", 37:"L",
        38:"J", 39:"'", 40:"K", 41:";", 42:"\\", 43:",", 44:"/", 45:"N", 46:"M",
        47:".", 48:"⇥", 49:"Space", 50:"`", 65:"Keypad .", 67:"Keypad *", 69:"Keypad +",
        75:"Keypad /", 76:"Keypad ↩", 78:"Keypad -", 81:"Keypad =", 82:"Keypad 0",
        83:"Keypad 1", 84:"Keypad 2", 85:"Keypad 3", 86:"Keypad 4", 87:"Keypad 5",
        88:"Keypad 6", 89:"Keypad 7", 91:"Keypad 8", 92:"Keypad 9",
        64:"F17", 79:"F18", 80:"F19", 90:"F20", 96:"F5", 97:"F6", 98:"F7", 99:"F3",
        100:"F8", 101:"F9", 103:"F11", 105:"F13", 106:"F16", 107:"F14", 109:"F10",
        111:"F12", 113:"F15", 115:"↖", 116:"⇞", 118:"F4", 119:"↘", 120:"F2",
        121:"⇟", 122:"F1", 123:"←", 124:"→", 125:"↓", 126:"↑"
    ]
}
