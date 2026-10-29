// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 FindFix contributors

import Carbon.HIToolbox
import CoreGraphics
import XCTest
@testable import FindFix

final class DeleteKeyDecisionTests: XCTestCase {
    private let del = DeleteKeyDecision.forwardDeleteKeyCode
    private let fileList = FocusState.element(role: "AXOutline", subrole: nil)

    private func decide(finder: Bool = true,
                        key: Int64? = nil,
                        flags: CGEventFlags = [],
                        focus: FocusState? = nil,
                        permanent: Bool = false) -> DeleteKeyAction {
        DeleteKeyDecision.decide(finderIsFrontmost: finder,
                                 keyCode: key ?? del,
                                 flags: flags,
                                 focus: focus ?? fileList,
                                 deletePermanently: permanent)
    }

    // File selected: trash (or permanent when the sub-toggle is on).

    func testFileListFocusedTrashes() {
        XCTAssertEqual(decide(), .moveToTrash)
    }

    func testOtherFileViewsTrash() {
        for role in ["AXList", "AXBrowser", "AXGroup", "AXScrollArea", "AXTable", "AXImage"] {
            XCTAssertEqual(decide(focus: .element(role: role, subrole: nil)), .moveToTrash, role)
        }
    }

    func testDesktopWithNoFocusedElementTrashes() {
        XCTAssertEqual(decide(focus: FocusState.none), .moveToTrash)
    }

    func testPermanentSubToggle() {
        XCTAssertEqual(decide(permanent: true), .deletePermanently)
    }

    func testFnFlagFromMacKeyboardIsAllowed() {
        XCTAssertEqual(decide(flags: [.maskSecondaryFn, .maskNumericPad]), .moveToTrash)
    }

    // Text field focused: never interfere.

    func testRenamingTextFieldPassesThrough() {
        XCTAssertEqual(decide(focus: .element(role: "AXTextField", subrole: nil)), .passThrough)
        XCTAssertEqual(decide(focus: .element(role: "AXTextField", subrole: nil), permanent: true), .passThrough)
    }

    func testSearchFieldPassesThrough() {
        XCTAssertEqual(decide(focus: .element(role: "AXTextField", subrole: "AXSearchField")), .passThrough)
        XCTAssertEqual(decide(focus: .element(role: "AXSearchField", subrole: nil)), .passThrough)
    }

    func testOtherTextInputsPassThrough() {
        for role in ["AXTextArea", "AXComboBox", "AXSecureTextField", "AXWebArea"] {
            XCTAssertEqual(decide(focus: .element(role: role, subrole: nil)), .passThrough, role)
        }
    }

    func testUnknownFocusPassesThrough() {
        XCTAssertEqual(decide(focus: .unavailable), .passThrough)
    }

    // Wrong app, key or modifiers.

    func testOtherAppPassesThrough() {
        XCTAssertEqual(decide(finder: false), .passThrough)
    }

    func testBackspaceKeyPassesThrough() {
        XCTAssertEqual(decide(key: Int64(kVK_Delete)), .passThrough)
    }

    func testModifiedDeletePassesThrough() {
        for flags: CGEventFlags in [.maskCommand, .maskControl, .maskAlternate, .maskShift] {
            XCTAssertEqual(decide(flags: flags), .passThrough)
        }
    }

    // The ⌦ event itself becomes Finder's Move to Trash shortcut.

    func testRewriteMakesCommandBackspace() throws {
        let event = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ForwardDelete), keyDown: true))
        event.flags = [.maskSecondaryFn, .maskNumericPad]
        DeleteKeyDecision.rewriteAsMoveToTrash(event)
        XCTAssertEqual(event.getIntegerValueField(.keyboardEventKeycode), Int64(kVK_Delete))
        XCTAssertEqual(event.flags.intersection(.shortcutModifiers), .maskCommand)
    }
}
