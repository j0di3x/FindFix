// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 FindFix contributors
// Focus check follows Vorssaint FinderCutPaste.isEditingText() (https://github.com/vorssaint/vorssaint-utils).

import AppKit
import ApplicationServices

/// Shared checks for the Finder keyboard features.
enum FinderContext {
    /// Finder's pid when it is the frontmost app (a Finder window or the Desktop).
    static func frontmostFinderPID() -> pid_t? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier == FinderBridge.bundleID else { return nil }
        return app.processIdentifier
    }

    static func focus(inFinder pid: pid_t) -> FocusState {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(AX.app(pid), kAXFocusedUIElementAttribute as CFString, &value)
        if status == .noValue { return .none }
        guard status == .success, let value, CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return .unavailable
        }
        let element = value as! AXUIElement
        AXUIElementSetMessagingTimeout(element, AX.timeout)
        guard let role = AX.role(element) else { return .unavailable }
        return .element(role: role, subrole: AX.subrole(element))
    }

    /// Finder is in front and focus is on files, not on a text field.
    static func fileFocusedFinderPID() -> pid_t? {
        guard let pid = frontmostFinderPID(), !focus(inFinder: pid).isTextInput else { return nil }
        return pid
    }
}
