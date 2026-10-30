// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint; modifications Copyright (C) 2026 FindFix contributors
// Adapted from Vorssaint FinderRenameService.swift (https://github.com/vorssaint/vorssaint-utils).

import AppKit
import Carbon.HIToolbox

/// A chosen shortcut starts renaming the selected Finder item, by turning the
/// key press into Finder's own rename key (Return) inside the tap.
final class FinderRenameFeature: Feature {
    let id = "finderRename"
    let title = String(localized: "Rename shortcut in Finder")
    let summary = String(localized: "Your shortcut starts renaming the selected item.")
    let requiredPermissions: Set<Permission> = [.accessibility]
    let eventMask = FindFix.eventMask(.keyDown)

    private let store: SettingsStore

    init(store: SettingsStore) {
        self.store = store
    }

    func handle(type: CGEventType, event: CGEvent) -> TapResult {
        guard store.renameShortcut.matches(keyCode: event.getIntegerValueField(.keyboardEventKeycode),
                                           flags: event.flags),
              FinderContext.fileFocusedFinderPID() != nil else { return .pass }
        event.setIntegerValueField(.keyboardEventKeycode, value: Int64(kVK_Return))
        event.flags = []
        return .pass
    }
}
