// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint; modifications Copyright (C) 2026 FindFix contributors
// Adapted from Vorssaint WindowServerSupport.swift (https://github.com/vorssaint/vorssaint-utils).

import CoreGraphics
import Darwin
import Foundation

enum TrafficLightButton {
    case close
    case zoom
}

struct TrafficLightCandidate {
    let pid: pid_t
    let windowID: CGWindowID
    let frame: CGRect
}

/// Cheap WindowServer lookups that run before any Accessibility query, so
/// ordinary clicks never wait on another process.
enum WindowServer {
    static func onScreenWindows() -> [[String: Any]] {
        CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
    }

    static func bounds(of window: [String: Any]) -> CGRect? {
        guard let raw = window[kCGWindowBounds as String] as? NSDictionary else { return nil }
        return CGRect(dictionaryRepresentation: raw)
    }

    /// The front-most normal window under `point`, if the point sits in the
    /// area where that window draws the given traffic light. A click on the
    /// window in front never falls through to one behind it.
    static func trafficLightCandidate(at point: CGPoint,
                                      button: TrafficLightButton,
                                      pidIsEligible: (pid_t) -> Bool) -> TrafficLightCandidate? {
        let ownPID = getpid()
        for window in onScreenWindows() {
            guard let bounds = bounds(of: window),
                  bounds.width >= 80, bounds.height >= 80,
                  bounds.contains(point) else { continue }
            guard (window[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                  (window[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1 > 0,
                  let pid = (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                  pid != ownPID,
                  let number = (window[kCGWindowNumber as String] as? NSNumber)?.uint32Value else { continue }
            guard pidIsEligible(pid), contains(point, inTrafficLightAreaOf: bounds, button: button) else {
                return nil
            }
            return TrafficLightCandidate(pid: pid, windowID: CGWindowID(number), frame: bounds)
        }
        return nil
    }

    static func contains(_ point: CGPoint, inTrafficLightAreaOf bounds: CGRect, button: TrafficLightButton) -> Bool {
        let dx = point.x - bounds.minX
        let dy = point.y - bounds.minY
        guard dy >= -6, dy <= 46 else { return false }
        switch button {
        case .close: return dx >= -6 && dx <= 52
        case .zoom: return dx >= 42 && dx <= 104
        }
    }

    /// Whether the app still shows a normal-sized window on screen.
    static func hasVisibleWindow(pid: pid_t) -> Bool {
        onScreenWindows().contains { window in
            (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid
                && (window[kCGWindowLayer as String] as? NSNumber)?.intValue == 0
                && (window[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1 > 0
                && (bounds(of: window).map { $0.width >= 80 && $0.height >= 80 } ?? false)
        }
    }
}
