// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 FindFix contributors

import Carbon.HIToolbox
import CoreGraphics
import Foundation

/// A key plus modifiers. `modifiers` holds `CGEventFlags` bits, which match
/// `NSEvent.ModifierFlags` bit for bit for command, control, option and shift.
struct Shortcut: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: UInt64

    static let renameDefault = Shortcut(keyCode: UInt16(kVK_ANSI_R),
                                        modifiers: CGEventFlags.maskControl.rawValue)

    var flags: CGEventFlags { CGEventFlags(rawValue: modifiers).intersection(.shortcutModifiers) }

    init(keyCode: UInt16, modifiers: UInt64) {
        self.keyCode = keyCode
        self.modifiers = CGEventFlags(rawValue: modifiers).intersection(.shortcutModifiers).rawValue
    }

    func matches(keyCode: Int64, flags: CGEventFlags) -> Bool {
        keyCode == Int64(self.keyCode) && flags.intersection(.shortcutModifiers) == self.flags
    }

    /// Function keys work alone; anything else needs a modifier so the
    /// shortcut never eats plain typing.
    var isValid: Bool { !flags.isEmpty || Self.functionKeys[Int(keyCode)] != nil }

    var displayString: String {
        var text = ""
        if flags.contains(.maskControl) { text += "⌃" }
        if flags.contains(.maskAlternate) { text += "⌥" }
        if flags.contains(.maskShift) { text += "⇧" }
        if flags.contains(.maskCommand) { text += "⌘" }
        return text + Self.keyName(Int(keyCode))
    }

    private static let functionKeys: [Int: String] = [
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]

    private static let namedKeys: [Int: String] = [
        kVK_Return: "↩", kVK_Tab: "⇥", kVK_Space: "Space", kVK_Delete: "⌫", kVK_Escape: "⎋",
        kVK_ForwardDelete: "⌦", kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑",
        kVK_DownArrow: "↓", kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
    ]

    static func keyName(_ keyCode: Int) -> String {
        if let name = functionKeys[keyCode] ?? namedKeys[keyCode] { return name }
        return translated(keyCode)?.uppercased() ?? "#\(keyCode)"
    }

    /// The character the key types on the current keyboard layout.
    private static func translated(_ keyCode: Int) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue() as Data
        return data.withUnsafeBytes { buffer -> String? in
            guard let layout = buffer.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return nil }
            var deadKeys: UInt32 = 0
            var length = 0
            var chars = [UniChar](repeating: 0, count: 4)
            let status = UCKeyTranslate(layout, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0,
                                        UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
                                        &deadKeys, chars.count, &length, &chars)
            guard status == noErr, length > 0 else { return nil }
            return String(utf16CodeUnits: chars, count: length)
        }
    }
}
