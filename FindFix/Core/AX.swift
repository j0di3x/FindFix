// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint; modifications Copyright (C) 2026 FindFix contributors
// Adapted from Vorssaint WindowMaximizer.swift (https://github.com/vorssaint/vorssaint-utils).

import AppKit
import ApplicationServices

/// Small Accessibility helpers. Every element made here gets a short
/// messaging timeout so a busy app can never stall the event tap for long.
enum AX {
    static let timeout: Float = 0.3

    static func app(_ pid: pid_t) -> AXUIElement {
        let element = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(element, timeout)
        return element
    }

    /// Hit test inside one app, so the timeout stays on that app's element
    /// instead of the system-wide one (which would change it for every call).
    static func element(at point: CGPoint, inApp pid: pid_t) -> AXUIElement? {
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(app(pid), Float(point.x), Float(point.y), &element) == .success,
              let element else { return nil }
        AXUIElementSetMessagingTimeout(element, timeout)
        return element
    }

    static func element(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        let result = value as! AXUIElement
        AXUIElementSetMessagingTimeout(result, timeout)
        return result
    }

    static func elements(_ element: AXUIElement, _ attribute: String) -> [AXUIElement]? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? [AXUIElement]
    }

    static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    static func bool(_ element: AXUIElement, _ attribute: String) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? Bool
    }

    static func role(_ element: AXUIElement) -> String? { string(element, kAXRoleAttribute) }
    static func subrole(_ element: AXUIElement) -> String? { string(element, kAXSubroleAttribute) }

    static func pid(_ element: AXUIElement) -> pid_t {
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        return pid
    }

    // MARK: Frames (AX coordinates: origin at top-left of the menu-bar screen)

    static func frame(_ element: AXUIElement) -> CGRect? {
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let positionRef, let sizeRef,
              CFGetTypeID(positionRef) == AXValueGetTypeID(), CFGetTypeID(sizeRef) == AXValueGetTypeID()
        else { return nil }
        var origin = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionRef as! AXValue, .cgPoint, &origin),
              AXValueGetValue(sizeRef as! AXValue, .cgSize, &size),
              size.width > 0, size.height > 0 else { return nil }
        return CGRect(origin: origin, size: size)
    }

    @discardableResult
    static func setFrame(_ frame: CGRect, of window: AXUIElement) -> Bool {
        // Position, size, position: the second move fixes windows that clamp
        // the size against their old position.
        let moved = setPosition(frame.origin, of: window)
        let sized = setSize(frame.size, of: window)
        return moved && sized && setPosition(frame.origin, of: window)
    }

    static func setPosition(_ point: CGPoint, of element: AXUIElement) -> Bool {
        var point = point
        guard let value = AXValueCreate(.cgPoint, &point) else { return false }
        return AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value) == .success
    }

    static func setSize(_ size: CGSize, of element: AXUIElement) -> Bool {
        var size = size
        guard let value = AXValueCreate(.cgSize, &size) else { return false }
        return AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value) == .success
    }

    /// Top edge of the menu-bar screen in AppKit coordinates; AX and
    /// CoreGraphics measure y down from it.
    static var primaryScreenTop: CGFloat {
        let primary = NSScreen.screens.first { abs($0.frame.minX) < 0.5 && abs($0.frame.minY) < 0.5 }
        return (primary ?? NSScreen.screens.first)?.frame.maxY ?? 0
    }

    static func axRect(fromAppKit rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: primaryScreenTop - rect.maxY, width: rect.width, height: rect.height)
    }

    static func appKitRect(fromAX rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: primaryScreenTop - rect.maxY, width: rect.width, height: rect.height)
    }
}
