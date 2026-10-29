// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 FindFix contributors

import Foundation
import ServiceManagement

/// Open at login, through the system's own login item list (System Settings ›
/// General › Login Items), so the user can also switch it off there.
enum LoginItem {
    private static let configuredKey = "launchAtLogin.configured"

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// The system shows a notice when a login item is added; it may also ask
    /// the user to approve it in System Settings.
    static var needsApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("FindFix: login item change failed: \(error.localizedDescription)")
        }
    }

    /// On by default: switched on once, the first time this version runs.
    /// Later changes are the user's and are left alone.
    static func enableOnce(defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: configuredKey) else { return }
        defaults.set(true, forKey: configuredKey)
        if !isEnabled { setEnabled(true) }
    }
}
