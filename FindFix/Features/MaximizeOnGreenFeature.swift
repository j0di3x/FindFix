// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint; modifications Copyright (C) 2026 FindFix contributors
// Adapted from Vorssaint WindowMaximizer.swift (https://github.com/vorssaint/vorssaint-utils).

import AppKit
import ApplicationServices

/// The green button fills the screen's visible frame (below the menu bar,
/// clear of the Dock) instead of entering a full-screen Space; a second click
/// restores the old frame. Option-click keeps the native behavior.
final class MaximizeOnGreenFeature: Feature {
    let id = "maximizeOnGreen"
    let title = "Maximize on green button"
    let summary = "The green button fills the desktop area instead of entering full screen. Click again to restore. ⌥-click keeps the macOS behavior."
    let requiredPermissions: Set<Permission> = [.accessibility]
    let eventMask = FindFix.eventMask(.leftMouseDown, .leftMouseUp)

    private struct Target {
        let window: AXUIElement
        let windowID: CGWindowID
        let buttonFrame: CGRect
    }

    private var pending: Target?
    private var originalFrames: [CGWindowID: CGRect] = [:]
    private let tolerance: CGFloat = 4

    func stop() {
        pending = nil
        originalFrames.removeAll()
    }

    func handle(type: CGEventType, event: CGEvent) -> TapResult {
        switch type {
        case .leftMouseDown:
            pending = nil
            guard event.flags.intersection(.shortcutModifiers).isEmpty,
                  let target = target(at: event.location) else { return .pass }
            pending = target
            return .consume
        case .leftMouseUp:
            guard let target = pending else { return .pass }
            pending = nil
            if target.buttonFrame.insetBy(dx: -8, dy: -8).contains(event.location) {
                DispatchQueue.main.async { [weak self] in self?.toggle(target) }
            }
            return .consume
        default:
            return .pass
        }
    }

    private func target(at point: CGPoint) -> Target? {
        guard let candidate = WindowServer.trafficLightCandidate(at: point, button: .zoom,
                                                                 pidIsEligible: { _ in true }),
              let element = AX.element(at: point, inApp: candidate.pid),
              let subrole = AX.subrole(element),
              subrole == (kAXZoomButtonSubrole as String) || subrole == (kAXFullScreenButtonSubrole as String),
              AX.bool(element, kAXEnabledAttribute) ?? true,
              let window = AX.element(element, kAXWindowAttribute),
              AX.role(window) == (kAXWindowRole as String),
              AX.bool(window, "AXFullScreen") != true,
              let buttonFrame = AX.frame(element) else { return nil }
        return Target(window: window, windowID: candidate.windowID, buttonFrame: buttonFrame)
    }

    private func toggle(_ target: Target) {
        guard let current = AX.frame(target.window), let screen = bestScreen(for: current) else { return }
        let maximized = AX.axRect(fromAppKit: screen.visibleFrame)
        if isClose(current, maximized), let original = originalFrames.removeValue(forKey: target.windowID) {
            AX.setFrame(original, of: target.window)
            return
        }
        guard !isClose(current, maximized) else { return }
        originalFrames[target.windowID] = current
        AX.setFrame(maximized, of: target.window)
        // Some apps keep an edge out from under a side Dock and refuse the
        // size; coming at it from a little up and left makes them take it.
        if let actual = AX.frame(target.window),
           actual.width > maximized.width + 0.5 || actual.height > maximized.height + 0.5 {
            _ = AX.setPosition(CGPoint(x: maximized.minX - tolerance, y: maximized.minY - tolerance), of: target.window)
            AX.setFrame(maximized, of: target.window)
        }
    }

    private func isClose(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) <= tolerance && abs(a.minY - b.minY) <= tolerance
            && abs(a.width - b.width) <= tolerance && abs(a.height - b.height) <= tolerance
    }

    private func bestScreen(for axFrame: CGRect) -> NSScreen? {
        let frame = AX.appKitRect(fromAX: axFrame)
        func area(_ screen: NSScreen) -> CGFloat {
            let overlap = screen.frame.intersection(frame)
            return overlap.isNull ? 0 : overlap.width * overlap.height
        }
        return NSScreen.screens.max { area($0) < area($1) } ?? NSScreen.main
    }
}
