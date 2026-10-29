// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 FindFix contributors

import CoreGraphics
import XCTest
@testable import FindFix

final class FeatureLifecycleTests: XCTestCase {
    private var store: SettingsStore!
    private var permissions: FakePermissions!
    private var taps: FakeTapFactory!
    private var mouse: FakeFeature!
    private var keys: FakeFeature!
    private var manager: FeatureManager!

    override func setUp() {
        store = SettingsStore(defaults: makeTestDefaults())
        permissions = FakePermissions()
        taps = FakeTapFactory()
        mouse = FakeFeature(id: "mouse", mask: eventMask(.leftMouseDown))
        keys = FakeFeature(id: "keys", mask: eventMask(.keyDown))
        manager = makeManager()
    }

    private func makeManager() -> FeatureManager {
        FeatureManager(store: store, features: [mouse, keys], permissions: permissions, tapFactory: taps)
    }

    func testNothingEnabledMeansNoTap() {
        manager.apply()
        XCTAssertNil(manager.tap)
        XCTAssertTrue(taps.made.isEmpty)
        XCTAssertEqual(mouse.startCount, 0)
    }

    func testSwitchingOnStartsFeatureAndCreatesTap() {
        manager.setEnabled("mouse", true)
        XCTAssertEqual(mouse.startCount, 1)
        XCTAssertTrue(manager.isRunning("mouse"))
        XCTAssertEqual(taps.live.count, 1)
        XCTAssertEqual(taps.live.first?.mask, eventMask(.leftMouseDown))
    }

    func testOneSharedTapWithUnionMask() {
        manager.setEnabled("mouse", true)
        manager.setEnabled("keys", true)
        XCTAssertEqual(taps.live.count, 1)
        XCTAssertEqual(taps.live.first?.mask, eventMask(.leftMouseDown, .keyDown))
    }

    func testSwitchingOffStopsFeatureAndShrinksTap() {
        manager.setEnabled("mouse", true)
        manager.setEnabled("keys", true)
        manager.setEnabled("mouse", false)
        XCTAssertEqual(mouse.stopCount, 1)
        XCTAssertFalse(manager.isRunning("mouse"))
        XCTAssertEqual(taps.live.count, 1)
        XCTAssertEqual(taps.live.first?.mask, eventMask(.keyDown))
    }

    func testLastFeatureOffRemovesTap() {
        manager.setEnabled("keys", true)
        manager.setEnabled("keys", false)
        XCTAssertNil(manager.tap)
        XCTAssertTrue(taps.live.isEmpty)
        XCTAssertEqual(keys.stopCount, 1)
    }

    func testMasterSwitchStopsEverythingAndRestores() {
        manager.setEnabled("mouse", true)
        manager.setEnabled("keys", true)
        manager.masterEnabled = false
        XCTAssertEqual(mouse.stopCount, 1)
        XCTAssertEqual(keys.stopCount, 1)
        XCTAssertNil(manager.tap)
        XCTAssertTrue(taps.live.isEmpty)
        // Individual switches are kept while the master is off.
        XCTAssertTrue(manager.isEnabled("mouse"))

        manager.masterEnabled = true
        XCTAssertEqual(mouse.startCount, 2)
        XCTAssertEqual(keys.startCount, 2)
        XCTAssertEqual(taps.live.count, 1)
    }

    func testRepeatedApplyIsIdempotent() {
        manager.setEnabled("mouse", true)
        manager.apply()
        manager.apply()
        XCTAssertEqual(mouse.startCount, 1)
        XCTAssertEqual(taps.made.count, 1)
    }

    func testPermissionAskedOnlyWhenSwitchedOnAndMissing() {
        permissions.granted = []
        manager.apply()
        XCTAssertTrue(permissions.requests.isEmpty)

        manager.setEnabled("mouse", true)
        XCTAssertEqual(permissions.requests, [.accessibility])
        XCTAssertFalse(manager.isRunning("mouse"))
        XCTAssertNil(manager.tap)

        // Granted later (the Accessibility notification calls apply()).
        permissions.granted = [.accessibility]
        manager.apply()
        XCTAssertTrue(manager.isRunning("mouse"))
        XCTAssertEqual(permissions.requests, [.accessibility])
    }

    func testNoPermissionPromptWhenAlreadyGranted() {
        manager.setEnabled("mouse", true)
        XCTAssertTrue(permissions.requests.isEmpty)
    }

    func testSavedSwitchesApplyOnLaunch() {
        store.setEnabled("keys", true)
        let fresh = makeManager()
        fresh.apply()
        XCTAssertTrue(fresh.isRunning("keys"))
        XCTAssertFalse(fresh.isRunning("mouse"))
    }

    func testDispatchRoutesByMaskAndHonorsConsume() throws {
        manager.setEnabled("mouse", true)
        manager.setEnabled("keys", true)
        let event = try XCTUnwrap(CGEvent(source: nil))

        XCTAssertEqual(manager.dispatch(type: .keyDown, event: event), .pass)
        XCTAssertEqual(keys.handled, [.keyDown])
        XCTAssertEqual(mouse.handled, [])

        keys.result = .consume
        XCTAssertEqual(taps.live.first?.handler(.keyDown, event), .consume)
    }

    func testStoppedFeatureGetsNoEvents() throws {
        manager.setEnabled("keys", true)
        manager.setEnabled("keys", false)
        let event = try XCTUnwrap(CGEvent(source: nil))
        XCTAssertEqual(manager.dispatch(type: .keyDown, event: event), .pass)
        XCTAssertTrue(keys.handled.isEmpty)
    }

    func testLiveFeaturesHaveUniqueIDsAndMasks() {
        let live = FeatureManager.live()
        XCTAssertEqual(Set(live.features.map(\.id)).count, 5)
        XCTAssertTrue(live.features.allSatisfy { $0.eventMask != 0 })
    }
}
