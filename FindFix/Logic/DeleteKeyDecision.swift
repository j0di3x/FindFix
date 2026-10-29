// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 FindFix contributors

import Carbon.HIToolbox
import CoreGraphics

enum DeleteKeyAction: Equatable {
    case passThrough
    case moveToTrash
    case deletePermanently
}

/// Pure decision for the Delete (forward delete, ⌦) key. Kept free of
/// AppKit and Accessibility so it can be unit tested.
enum DeleteKeyDecision {
    /// ⌦ on PC-style keyboards; fn+⌫ on Mac keyboards sends the same code.
    static let forwardDeleteKeyCode = Int64(kVK_ForwardDelete)

    static func decide(finderIsFrontmost: Bool,
                       keyCode: Int64,
                       flags: CGEventFlags,
                       focus: FocusState,
                       deletePermanently: Bool) -> DeleteKeyAction {
        guard finderIsFrontmost,
              keyCode == forwardDeleteKeyCode,
              flags.intersection(.shortcutModifiers).isEmpty,
              !focus.isTextInput else { return .passThrough }
        return deletePermanently ? .deletePermanently : .moveToTrash
    }
}
