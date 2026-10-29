// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 FindFix contributors

import Foundation

/// Every persisted setting, backed by UserDefaults. Tests pass their own suite.
final class SettingsStore {
    enum Key {
        static let master = "masterEnabled"
        static let quitExclusions = "quitOnClose.excludedBundleIDs"
        static let permanentDelete = "finderDeleteKey.permanent"
        static let renameShortcut = "finderRename.shortcut"
        static let autoCheckUpdates = "updates.autoCheck"
        static let skippedVersion = "updates.skippedVersion"
        static let lastUpdateCheck = "updates.lastCheck"
        static func feature(_ id: String) -> String { "feature.\(id).enabled" }
    }

    static let defaultQuitExclusions = ["com.apple.finder"]

    let defaults: UserDefaults
    private var cachedShortcut: Shortcut?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var masterEnabled: Bool {
        get { defaults.object(forKey: Key.master) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.master) }
    }

    /// Features start off, so no permission is asked for until the user
    /// switches one on.
    func isEnabled(_ featureID: String) -> Bool {
        defaults.bool(forKey: Key.feature(featureID))
    }

    func setEnabled(_ featureID: String, _ enabled: Bool) {
        defaults.set(enabled, forKey: Key.feature(featureID))
    }

    var quitExclusions: [String] {
        get { defaults.stringArray(forKey: Key.quitExclusions) ?? Self.defaultQuitExclusions }
        set {
            var seen = Set<String>()
            let cleaned = newValue
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && seen.insert($0).inserted }
            defaults.set(cleaned, forKey: Key.quitExclusions)
        }
    }

    var permanentDelete: Bool {
        get { defaults.bool(forKey: Key.permanentDelete) }
        set { defaults.set(newValue, forKey: Key.permanentDelete) }
    }

    /// Cached because the rename feature reads it on every Finder key press.
    var renameShortcut: Shortcut {
        get {
            if let cachedShortcut { return cachedShortcut }
            let stored = defaults.data(forKey: Key.renameShortcut)
                .flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) }
            let value = stored.flatMap { $0.isValid ? $0 : nil } ?? .renameDefault
            cachedShortcut = value
            return value
        }
        set {
            cachedShortcut = newValue
            defaults.set(try? JSONEncoder().encode(newValue), forKey: Key.renameShortcut)
        }
    }

    var autoCheckUpdates: Bool {
        get { defaults.object(forKey: Key.autoCheckUpdates) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.autoCheckUpdates) }
    }

    /// A version the user chose to skip: automatic checks stay quiet about it.
    var skippedVersion: String? {
        get { defaults.string(forKey: Key.skippedVersion) }
        set { defaults.set(newValue, forKey: Key.skippedVersion) }
    }

    var lastUpdateCheck: Date? {
        get { defaults.object(forKey: Key.lastUpdateCheck) as? Date }
        set { defaults.set(newValue, forKey: Key.lastUpdateCheck) }
    }
}
