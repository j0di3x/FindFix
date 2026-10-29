// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 FindFix contributors

import AppKit
import SwiftUI

@main
struct FindFixApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra("FindFix", systemImage: "folder.badge.gearshape") {
            MenuContent(manager: delegate.manager, openSettings: delegate.showSettings)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let manager = FeatureManager.live()
    private lazy var settings = SettingsWindowController(manager: manager)

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hosted unit tests must not install taps or show permission prompts.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        manager.activate()
        // First launch: nothing is on yet, so show where to switch things on.
        if !UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            showSettings()
        }
    }

    /// Clicking the Dock icon (only there while Settings is open or
    /// minimized) brings the window back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }

    func showSettings() {
        settings.show()
    }
}

struct MenuContent: View {
    @ObservedObject var manager: FeatureManager
    let openSettings: () -> Void

    var body: some View {
        Toggle("FindFix Enabled", isOn: Binding(get: { manager.masterEnabled },
                                                 set: { manager.masterEnabled = $0 }))
        Divider()
        Button("Settings…", action: openSettings)
            .keyboardShortcut(",")
        Divider()
        Button("Quit FindFix") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
