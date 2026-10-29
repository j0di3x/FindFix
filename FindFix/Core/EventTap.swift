// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 FindFix contributors
// Tap lifecycle adapted from Vorssaint (https://github.com/vorssaint/vorssaint-utils).

import ApplicationServices
import CoreGraphics
import Foundation

typealias EventTapHandler = (CGEventType, CGEvent) -> TapResult

protocol EventTapping: AnyObject {
    var mask: CGEventMask { get }
    func invalidate()
}

protocol EventTapFactory {
    func makeTap(mask: CGEventMask, handler: @escaping EventTapHandler) -> EventTapping?
}

/// Marks events FindFix posts itself so the tap lets them through untouched.
enum SyntheticEvent {
    static let marker: Int64 = 0x4644_4658 // "FDFX"

    static func isOwn(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.eventSourceUserData) == marker
    }

    static func postKey(_ keyCode: CGKeyCode, flags: CGEventFlags = [], to pid: pid_t) {
        let source = CGEventSource(stateID: .privateState)
        for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: down) else { continue }
            event.flags = flags
            event.setIntegerValueField(.eventSourceUserData, value: marker)
            event.postToPid(pid)
        }
    }
}

struct SystemEventTapFactory: EventTapFactory {
    func makeTap(mask: CGEventMask, handler: @escaping EventTapHandler) -> EventTapping? {
        SystemEventTap(mask: mask, handler: handler)
    }
}

/// The single session event tap, on the main run loop. It exists only while
/// some running feature asks for events.
final class SystemEventTap: EventTapping {
    let mask: CGEventMask
    private let handler: EventTapHandler
    private var port: CFMachPort?
    private var source: CFRunLoopSource?

    init?(mask: CGEventMask, handler: @escaping EventTapHandler) {
        self.mask = mask
        self.handler = handler
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let tap = Unmanaged<SystemEventTap>.fromOpaque(userInfo).takeUnretainedValue()
                return tap.route(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return nil }
        self.port = port
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
    }

    deinit { invalidate() }

    func invalidate() {
        if let port { CGEvent.tapEnable(tap: port, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let port { CFMachPortInvalidate(port) }
        port = nil
        source = nil
    }

    private func route(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let port { CGEvent.tapEnable(tap: port, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        // A revoked Accessibility grant would make the AX lookups features do
        // hang inside the tap and freeze input, so step aside entirely.
        guard !SyntheticEvent.isOwn(event), AXIsProcessTrusted() else {
            return Unmanaged.passUnretained(event)
        }
        return handler(type, event) == .consume ? nil : Unmanaged.passUnretained(event)
    }
}
