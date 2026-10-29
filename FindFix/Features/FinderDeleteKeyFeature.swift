// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 FindFix contributors

import AppKit
import Carbon.HIToolbox

/// ⌦ in Finder moves the selection to the Trash, like ⌘⌫. While a text field
/// has focus (renaming, search) the key is left alone. Optional: delete
/// immediately, after a confirmation.
final class FinderDeleteKeyFeature: Feature {
    let id = "finderDeleteKey"
    let title = "Delete key in Finder"
    let summary = "⌦ (fn+⌫ on Mac keyboards) moves selected items to the Trash. Text fields keep the key."
    let requiredPermissions: Set<Permission> = [.accessibility]
    let eventMask = FindFix.eventMask(.keyDown)

    private let store: SettingsStore

    init(store: SettingsStore) {
        self.store = store
    }

    func handle(type: CGEventType, event: CGEvent) -> TapResult {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        // Cheap checks first: most key presses stop here.
        guard keyCode == DeleteKeyDecision.forwardDeleteKeyCode,
              let pid = FinderContext.frontmostFinderPID() else { return .pass }
        let action = DeleteKeyDecision.decide(finderIsFrontmost: true,
                                              keyCode: keyCode,
                                              flags: event.flags,
                                              focus: FinderContext.focus(inFinder: pid),
                                              deletePermanently: store.permanentDelete)
        switch action {
        case .passThrough:
            return .pass
        case .moveToTrash:
            DispatchQueue.main.async {
                SyntheticEvent.postKey(CGKeyCode(kVK_Delete), flags: .maskCommand, to: pid)
            }
            return .consume
        case .deletePermanently:
            FinderBridge.queue.async {
                let urls = FinderBridge.selectionURLs()
                DispatchQueue.main.async { Self.confirmAndDelete(urls) }
            }
            return .consume
        }
    }

    private static func confirmAndDelete(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = urls.count == 1
            ? "Delete “\(urls[0].lastPathComponent)” immediately?"
            : "Delete \(urls.count) items immediately?"
        alert.informativeText = "This can’t be undone. The items will not go to the Trash."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let failed = urls.filter { url in
            (try? FileManager.default.removeItem(at: url)) == nil
        }
        if !failed.isEmpty {
            let error = NSAlert()
            error.messageText = "Could not delete \(failed.count) item(s)."
            error.informativeText = failed.map(\.path).joined(separator: "\n")
            error.runModal()
        }
    }
}
