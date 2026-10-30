// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint; modifications Copyright (C) 2026 FindFix contributors
// Adapted from Vorssaint AutoQuitService.swift (https://github.com/vorssaint/vorssaint-utils).

import AppKit
import ApplicationServices

/// A click on a window's red close button quits the app once its last window
/// is gone. Only clicks are watched (no per-app observers), and the check runs
/// a few times after the click because a closing window fades out first.
final class QuitOnCloseFeature: Feature {
    let id = "quitOnClose"
    let title = String(localized: "Quit on close")
    let summary = String(localized: "The red close button quits the app when its last window closes.")
    let requiredPermissions: Set<Permission> = [.accessibility]
    let eventMask = FindFix.eventMask(.leftMouseDown)

    private let store: SettingsStore
    /// Bumped on stop, so checks scheduled before it are dropped.
    private var generation = 0
    private var lastScheduled: [pid_t: Date] = [:]

    /// The window fades for about a quarter second; later looks cover slow
    /// machines. A final confirm skips transient zero-window states such as
    /// leaving full screen.
    private static let checkOffsets: [TimeInterval] = [0.35, 1.0, 2.2]
    private static let confirmDelay: TimeInterval = 1.2

    init(store: SettingsStore) {
        self.store = store
    }

    func stop() {
        generation += 1
        lastScheduled.removeAll()
    }

    func handle(type: CGEventType, event: CGEvent) -> TapResult {
        guard event.flags.intersection(.shortcutModifiers).isEmpty,
              let candidate = WindowServer.trafficLightCandidate(at: event.location, button: .close,
                                                                 pidIsEligible: isEligible),
              let element = AX.element(at: event.location, inApp: candidate.pid),
              AX.subrole(element) == (kAXCloseButtonSubrole as String) else { return .pass }
        scheduleChecks(pid: candidate.pid)
        return .pass
    }

    private func isEligible(_ pid: pid_t) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: pid),
              app.activationPolicy == .regular else { return false }
        guard let bundleID = app.bundleIdentifier else { return true }
        return !store.quitExclusions.contains(bundleID)
    }

    private func scheduleChecks(pid: pid_t) {
        let now = Date()
        if let last = lastScheduled[pid], now.timeIntervalSince(last) < 0.25 { return }
        lastScheduled[pid] = now
        let generation = generation
        let origin = DispatchTime.now()
        for offset in Self.checkOffsets {
            DispatchQueue.main.asyncAfter(deadline: origin + offset) { [weak self] in
                self?.check(pid: pid, generation: generation, confirm: true)
            }
        }
    }

    private func check(pid: pid_t, generation: Int, confirm: Bool) {
        guard generation == self.generation,
              let app = NSRunningApplication(processIdentifier: pid), !app.isTerminated,
              isEligible(pid), !hasWindows(pid: pid) else { return }
        if confirm {
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.confirmDelay) { [weak self] in
                self?.check(pid: pid, generation: generation, confirm: false)
            }
            return
        }
        lastScheduled[pid] = nil
        // Normal terminate: apps still ask about unsaved changes.
        app.terminate()
    }

    /// Any window counts, minimized or on another Space included. When
    /// Accessibility does not answer, assume windows remain.
    private func hasWindows(pid: pid_t) -> Bool {
        if WindowServer.hasVisibleWindow(pid: pid) { return true }
        guard let windows = AX.elements(AX.app(pid), kAXWindowsAttribute) else { return true }
        return windows.contains { window in
            AXUIElementSetMessagingTimeout(window, AX.timeout)
            let subrole = AX.subrole(window)
            return subrole == (kAXStandardWindowSubrole as String) || subrole == (kAXDialogSubrole as String)
        }
    }
}
