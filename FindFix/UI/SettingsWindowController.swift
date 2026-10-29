// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 FindFix contributors

import AppKit
import SwiftUI

/// Settings is a real Dock app while it is open: a Dock icon appears with the
/// window and goes away when Done hides it. The window has no close button,
/// so the only ways out are Done (⌘W), minimizing, or quitting FindFix.
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let manager: FeatureManager
    private var window: NSWindow?

    init(manager: FeatureManager) {
        self.manager = manager
    }

    var isShown: Bool { window?.isVisible == true || window?.isMiniaturized == true }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        NSApp.setActivationPolicy(.regular)
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        window?.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
    }

    private func makeWindow() -> NSWindow {
        let root = SettingsView(manager: manager, onDone: { [weak self] in self?.hide() })
        let window = NSWindow(contentViewController: NSHostingController(rootView: root))
        window.title = "FindFix"
        window.styleMask = [.titled, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("FindFixSettings")
        window.delegate = self
        window.center()
        return window
    }
}
