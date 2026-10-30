// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 FindFix contributors

import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Click, then press a key combination. Esc cancels. Plain keys without a
/// modifier are refused (function keys excepted).
struct ShortcutRecorder: View {
    @Binding var shortcut: Shortcut
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        HStack {
            Button(recording ? String(localized: "Press shortcut…") : shortcut.displayString) {
                recording ? stopRecording() : startRecording()
            }
            .frame(minWidth: 120)
            if shortcut != .renameDefault {
                Button("Default") { shortcut = .renameDefault }
            }
        }
        .onDisappear(perform: stopRecording)
    }

    private func startRecording() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) {
                stopRecording()
                return nil
            }
            let flags = CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue)).intersection(.shortcutModifiers)
            let candidate = Shortcut(keyCode: event.keyCode, modifiers: flags.rawValue)
            if candidate.isValid {
                shortcut = candidate
                stopRecording()
            } else {
                NSSound.beep()
            }
            return nil
        }
    }

    private func stopRecording() {
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
