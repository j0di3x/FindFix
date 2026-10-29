// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint; modifications Copyright (C) 2026 FindFix contributors
// Adapted from Vorssaint FinderRenameService.swift (https://github.com/vorssaint/vorssaint-utils).

import AppKit
import Carbon.HIToolbox

/// A chosen shortcut starts renaming the selected Finder item, by sending
/// Finder its own rename key (Return).
final class FinderRenameFeature: Feature {
    let id = "finderRename"
    let title = "Rename shortcut in Finder"
    let summary = "Your shortcut starts renaming the selected item."
    let requiredPermissions: Set<Permission> = [.accessibility]
    let eventMask = FindFix.eventMask(.keyDown)

    private let store: SettingsStore

    init(store: SettingsStore) {
        self.store = store
    }

    func handle(type: CGEventType, event: CGEvent) -> TapResult {
        guard store.renameShortcut.matches(keyCode: event.getIntegerValueField(.keyboardEventKeycode),
                                           flags: event.flags),
              let pid = FinderContext.fileFocusedFinderPID() else { return .pass }
        DispatchQueue.main.async {
            SyntheticEvent.postKey(CGKeyCode(kVK_Return), to: pid)
        }
        return .consume
    }
}
