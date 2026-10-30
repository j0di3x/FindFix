// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint; modifications Copyright (C) 2026 FindFix contributors
// Adapted from Vorssaint FinderCutPaste.swift (https://github.com/vorssaint/vorssaint-utils).

import AppKit
import Carbon.HIToolbox

/// ⌘X marks the Finder selection as cut; ⌘V in Finder moves it into the
/// current folder. Copying anything else in between cancels the cut, and in
/// text fields both keys work as usual.
final class FinderCutPasteFeature: Feature {
    let id = "finderCutPaste"
    let title = String(localized: "Cut & paste in Finder")
    let summary = String(localized: "⌘X then ⌘V moves files. Copying something else cancels the cut.")
    let requiredPermissions: Set<Permission> = [.accessibility, .automation]
    let eventMask = FindFix.eventMask(.keyDown)

    private var cutURLs: [URL] = []
    private var cutChangeCount = 0
    /// Bumped on stop and on each new cut, so a slow selection read that
    /// finishes late cannot revive a cancelled cut.
    private var generation = 0

    func stop() {
        generation += 1
        cutURLs = []
    }

    func handle(type: CGEventType, event: CGEvent) -> TapResult {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard keyCode == Int64(kVK_ANSI_X) || keyCode == Int64(kVK_ANSI_V),
              event.flags.intersection(.shortcutModifiers) == .maskCommand,
              event.getIntegerValueField(.keyboardEventAutorepeat) == 0,
              FinderContext.fileFocusedFinderPID() != nil else { return .pass }

        if keyCode == Int64(kVK_ANSI_X) {
            cut()
            return .consume
        }
        guard !cutURLs.isEmpty, NSPasteboard.general.changeCount == cutChangeCount else {
            cutURLs = []
            return .pass
        }
        paste()
        return .consume
    }

    private func cut() {
        generation += 1
        let generation = generation
        cutURLs = []
        FinderBridge.queue.async { [weak self] in
            let urls = FinderBridge.selectionURLs()
            DispatchQueue.main.async {
                guard let self, generation == self.generation, !urls.isEmpty else { return }
                self.cutURLs = urls
                self.cutChangeCount = NSPasteboard.general.changeCount
            }
        }
    }

    private func paste() {
        let urls = cutURLs
        cutURLs = []
        FinderBridge.queue.async {
            guard let folder = FinderBridge.insertionLocation() else { return }
            let movable = urls.filter { $0.deletingLastPathComponent().standardizedFileURL != folder.standardizedFileURL }
            FinderBridge.move(movable, into: folder)
        }
    }
}
