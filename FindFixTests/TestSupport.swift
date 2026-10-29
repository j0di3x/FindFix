// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 FindFix contributors

import CoreGraphics
import Foundation
@testable import FindFix

func makeTestDefaults() -> UserDefaults {
    let name = "FindFixTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}

final class FakeFeature: Feature {
    let id: String
    let title: String
    let summary = ""
    let requiredPermissions: Set<Permission>
    let eventMask: CGEventMask
    var result: TapResult = .pass

    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var handled: [CGEventType] = []

    init(id: String, mask: CGEventMask, permissions: Set<Permission> = [.accessibility]) {
        self.id = id
        self.title = id
        self.eventMask = mask
        self.requiredPermissions = permissions
    }

    func start() { startCount += 1 }
    func stop() { stopCount += 1 }
    func handle(type: CGEventType, event: CGEvent) -> TapResult {
        handled.append(type)
        return result
    }
}

final class FakePermissions: PermissionChecking {
    var granted: Set<Permission>
    private(set) var requests: [Permission] = []

    init(granted: Set<Permission> = Set(Permission.allCases)) {
        self.granted = granted
    }

    func isGranted(_ permission: Permission) -> Bool { granted.contains(permission) }
    func request(_ permission: Permission) { requests.append(permission) }
}

final class FakeTap: EventTapping {
    let mask: CGEventMask
    let handler: EventTapHandler
    private(set) var invalidated = false

    init(mask: CGEventMask, handler: @escaping EventTapHandler) {
        self.mask = mask
        self.handler = handler
    }

    func invalidate() { invalidated = true }
}

final class FakeTapFactory: EventTapFactory {
    private(set) var made: [FakeTap] = []
    var live: [FakeTap] { made.filter { !$0.invalidated } }

    func makeTap(mask: CGEventMask, handler: @escaping EventTapHandler) -> EventTapping? {
        let tap = FakeTap(mask: mask, handler: handler)
        made.append(tap)
        return tap
    }
}
