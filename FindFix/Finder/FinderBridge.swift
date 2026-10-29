// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint; modifications Copyright (C) 2026 FindFix contributors
// Adapted from Vorssaint FinderCutPaste.swift `FinderBridge` (https://github.com/vorssaint/vorssaint-utils).

import AppKit
import ApplicationServices

/// Talks to Finder with Apple Events, in process, so the Automation consent
/// belongs to FindFix. Every call blocks: run it on `FinderBridge.queue`.
enum FinderBridge {
    static let bundleID = "com.apple.finder"
    static let queue = DispatchQueue(label: "FindFix.FinderBridge", qos: .userInitiated)

    static func automationStatus(askIfNeeded: Bool) -> OSStatus {
        let target = NSAppleEventDescriptor(bundleIdentifier: bundleID)
        guard let desc = target.aeDesc else { return OSStatus(procNotFound) }
        return AEDeterminePermissionToAutomateTarget(desc, typeWildCard, typeWildCard, askIfNeeded)
    }

    /// The selected items in the front Finder window, or on the Desktop.
    static func selectionURLs() -> [URL] {
        guard automationStatus(askIfNeeded: true) == noErr else { return [] }
        let script = """
        tell application "Finder"
            set out to ""
            repeat with f in (get selection)
                set out to out & (POSIX path of (f as alias)) & linefeed
            end repeat
            return out
        end tell
        """
        guard let output = run(script) else { return [] }
        return output.split(whereSeparator: \.isNewline).map { URL(fileURLWithPath: String($0)) }
    }

    /// The folder a paste would land in: the front window's folder, or the Desktop.
    static func insertionLocation() -> URL? {
        guard automationStatus(askIfNeeded: true) == noErr else { return nil }
        let script = """
        tell application "Finder"
            return POSIX path of (insertion location as alias)
        end tell
        """
        guard let path = run(script)?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    /// Moves through Finder, so name clashes get Finder's own Replace/Keep
    /// Both dialog and the move can be undone with ⌘Z in Finder.
    @discardableResult
    static func move(_ urls: [URL], into folder: URL) -> Bool {
        guard !urls.isEmpty, automationStatus(askIfNeeded: true) == noErr else { return false }
        let targets = urls
            .map { "set end of targets to (POSIX file \(literal($0.path)) as alias)" }
            .joined(separator: "\n")
        let script = """
        with timeout of 600 seconds
            tell application "Finder"
                set targets to {}
                \(targets)
                move targets to folder (POSIX file \(literal(folder.path)) as alias)
            end tell
        end timeout
        """
        return run(script) != nil
    }

    static func literal(_ text: String) -> String {
        "\"" + text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    private static func run(_ source: String) -> String? {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return nil }
        let result = script.executeAndReturnError(&error)
        if error != nil { return nil }
        return result.stringValue ?? ""
    }
}
