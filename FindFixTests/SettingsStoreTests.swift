// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 FindFix contributors

import Carbon.HIToolbox
import XCTest
@testable import FindFix

final class SettingsStoreTests: XCTestCase {
    func testDefaults() {
        let store = SettingsStore(defaults: makeTestDefaults())
        XCTAssertTrue(store.masterEnabled)
        XCTAssertFalse(store.isEnabled("quitOnClose"))
        XCTAssertEqual(store.quitExclusions, ["com.apple.finder"])
        XCTAssertFalse(store.permanentDelete)
        XCTAssertEqual(store.renameShortcut, .renameDefault)
    }

    func testValuesSurviveANewStore() {
        let defaults = makeTestDefaults()
        let store = SettingsStore(defaults: defaults)
        store.masterEnabled = false
        store.setEnabled("finderCutPaste", true)
        store.quitExclusions = ["com.apple.finder", "com.apple.Safari"]
        store.permanentDelete = true
        let shortcut = Shortcut(keyCode: UInt16(kVK_F2), modifiers: 0)
        store.renameShortcut = shortcut

        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertFalse(reloaded.masterEnabled)
        XCTAssertTrue(reloaded.isEnabled("finderCutPaste"))
        XCTAssertFalse(reloaded.isEnabled("finderRename"))
        XCTAssertEqual(reloaded.quitExclusions, ["com.apple.finder", "com.apple.Safari"])
        XCTAssertTrue(reloaded.permanentDelete)
        XCTAssertEqual(reloaded.renameShortcut, shortcut)
    }

    func testExclusionsAreTrimmedAndDeduplicated() {
        let store = SettingsStore(defaults: makeTestDefaults())
        store.quitExclusions = [" com.apple.Safari ", "com.apple.Safari", "", "com.apple.finder"]
        XCTAssertEqual(store.quitExclusions, ["com.apple.Safari", "com.apple.finder"])
    }

    func testEmptyExclusionListStaysEmpty() {
        let defaults = makeTestDefaults()
        SettingsStore(defaults: defaults).quitExclusions = []
        XCTAssertEqual(SettingsStore(defaults: defaults).quitExclusions, [])
    }

    func testInvalidStoredShortcutFallsBackToDefault() throws {
        let defaults = makeTestDefaults()
        let bare = Shortcut(keyCode: UInt16(kVK_ANSI_R), modifiers: 0)
        defaults.set(try JSONEncoder().encode(bare), forKey: SettingsStore.Key.renameShortcut)
        XCTAssertEqual(SettingsStore(defaults: defaults).renameShortcut, .renameDefault)
    }

    func testShortcutMatchingIgnoresFnAndCapsLock() {
        let shortcut = Shortcut.renameDefault
        XCTAssertTrue(shortcut.matches(keyCode: Int64(kVK_ANSI_R), flags: [.maskControl, .maskSecondaryFn, .maskAlphaShift]))
        XCTAssertFalse(shortcut.matches(keyCode: Int64(kVK_ANSI_R), flags: [.maskControl, .maskShift]))
        XCTAssertFalse(shortcut.matches(keyCode: Int64(kVK_ANSI_T), flags: .maskControl))
    }
}
