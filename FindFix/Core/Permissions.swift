// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 FindFix contributors

import AppKit
import ApplicationServices

protocol PermissionChecking: AnyObject {
    func isGranted(_ permission: Permission) -> Bool
    /// Shows the system prompt (or opens System Settings) for `permission`.
    func request(_ permission: Permission)
}

final class SystemPermissions: PermissionChecking {
    func isGranted(_ permission: Permission) -> Bool {
        switch permission {
        case .accessibility: return AXIsProcessTrusted()
        case .automation: return FinderBridge.automationStatus(askIfNeeded: false) == noErr
        }
    }

    func request(_ permission: Permission) {
        switch permission {
        case .accessibility:
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        case .automation:
            // Blocks until the user answers the consent dialog.
            DispatchQueue.global(qos: .userInitiated).async {
                let status = FinderBridge.automationStatus(askIfNeeded: true)
                if status == OSStatus(errAEEventNotPermitted) {
                    DispatchQueue.main.async { Self.openSettings(.automation) }
                }
            }
        }
    }

    /// Clears FindFix's Accessibility entry, then asks again. Fixes a switch
    /// that shows on in System Settings but belongs to an older build.
    static func resetAccessibility() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", "Accessibility", bundleID]
        process.terminationHandler = { _ in
            DispatchQueue.main.async {
                SystemPermissions().request(.accessibility)
                openSettings(.accessibility)
            }
        }
        try? process.run()
    }

    static func openSettings(_ permission: Permission) {
        let anchor = permission == .accessibility ? "Privacy_Accessibility" : "Privacy_Automation"
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }
}
