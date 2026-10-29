// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 FindFix contributors

import CoreGraphics

enum Permission: String, CaseIterable {
    case accessibility
    /// Apple Events to Finder (System Settings > Privacy > Automation).
    case automation
}

enum TapResult {
    case pass
    case consume
}

/// One switchable behavior. Add a feature by writing one file that conforms to
/// this and listing it in `FeatureManager.live()`.
///
/// The manager calls `start()` when the feature turns on (master switch on,
/// own switch on, permissions present) and `stop()` when it turns off; a
/// stopped feature must leave nothing behind. Events matching `eventMask`
/// arrive in `handle` from the one shared event tap, on the main thread.
protocol Feature: AnyObject {
    var id: String { get }
    var title: String { get }
    var summary: String { get }
    var requiredPermissions: Set<Permission> { get }
    var eventMask: CGEventMask { get }
    func start()
    func stop()
    func handle(type: CGEventType, event: CGEvent) -> TapResult
}

extension Feature {
    func start() {}
    func stop() {}
    func handle(type: CGEventType, event: CGEvent) -> TapResult { .pass }
}

func eventMask(_ types: CGEventType...) -> CGEventMask {
    types.reduce(0) { $0 | (CGEventMask(1) << $1.rawValue) }
}

extension CGEventFlags {
    /// The four modifiers a shortcut is made of; fn, caps lock and the
    /// numeric-pad bit are left out.
    static let shortcutModifiers: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift]
}
