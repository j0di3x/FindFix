// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 FindFix contributors

import AppKit
import Carbon.HIToolbox

/// ⌦ in Finder moves the selection to the Trash, like ⌘⌫. While a text field
/// has focus (renaming, search) the key is left alone. Optional: delete
/// immediately, after a confirmation.
final class FinderDeleteKeyFeature: Feature {
    let id = "finderDeleteKey"
    let title = String(localized: "Delete key in Finder")
    let summary = String(localized: "⌦ (fn+⌫ on Mac keyboards) moves selected items to the Trash. Text fields keep the key.")
    let requiredPermissions: Set<Permission> = [.accessibility]
    let eventMask = FindFix.eventMask(.keyDown, .keyUp)

    private let store: SettingsStore
    /// The last ⌦ key-down became ⌘⌫, so its key-up must too.
    private var rewritingKey = false

    init(store: SettingsStore) {
        self.store = store
    }

    func handle(type: CGEventType, event: CGEvent) -> TapResult {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        // Cheap checks first: most key presses stop here.
        guard keyCode == DeleteKeyDecision.forwardDeleteKeyCode else { return .pass }
        if type == .keyUp {
            if rewritingKey {
                rewritingKey = false
                DeleteKeyDecision.rewriteAsMoveToTrash(event)
            }
            return .pass
        }
        guard let pid = FinderContext.frontmostFinderPID() else { return .pass }
        let action = DeleteKeyDecision.decide(finderIsFrontmost: true,
                                              keyCode: keyCode,
                                              flags: event.flags,
                                              focus: FinderContext.focus(inFinder: pid),
                                              deletePermanently: store.permanentDelete)
        // Holding the key must not delete item after item.
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        switch action {
        case .passThrough:
            rewritingKey = false
            return .pass
        case .moveToTrash:
            if isRepeat { return .consume }
            rewritingKey = true
            DeleteKeyDecision.rewriteAsMoveToTrash(event)
            return .pass
        case .deletePermanently:
            if isRepeat { return .consume }
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
            ? String(localized: "Delete “\(urls[0].lastPathComponent)” immediately?")
            : String(localized: "Delete \(urls.count) items immediately?")
        alert.informativeText = String(localized: "This can’t be undone. The items will not go to the Trash.")
        alert.addButton(withTitle: String(localized: "Delete"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let failed = urls.filter { url in
            (try? FileManager.default.removeItem(at: url)) == nil
        }
        if !failed.isEmpty {
            let error = NSAlert()
            error.messageText = String(localized: "Could not delete \(failed.count) item(s).")
            error.informativeText = failed.map(\.path).joined(separator: "\n")
            error.runModal()
        }
    }
}
