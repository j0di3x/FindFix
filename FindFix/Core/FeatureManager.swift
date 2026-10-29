// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 FindFix contributors

import AppKit
import Combine
import CoreGraphics

/// Owns the switches, starts and stops features to match them, and keeps one
/// shared event tap alive only while a running feature needs events.
final class FeatureManager: ObservableObject {
    let store: SettingsStore
    let features: [Feature]
    private let permissions: PermissionChecking
    private let tapFactory: EventTapFactory

    private(set) var runningIDs: Set<String> = []
    private(set) var tap: EventTapping?
    private var accessibilityObserver: NSObjectProtocol?

    init(store: SettingsStore,
         features: [Feature],
         permissions: PermissionChecking,
         tapFactory: EventTapFactory) {
        self.store = store
        self.features = features
        self.permissions = permissions
        self.tapFactory = tapFactory
    }

    static func live() -> FeatureManager {
        let store = SettingsStore()
        return FeatureManager(store: store,
                              features: [
                                  QuitOnCloseFeature(store: store),
                                  MaximizeOnGreenFeature(),
                                  FinderDeleteKeyFeature(store: store),
                                  FinderCutPasteFeature(),
                                  FinderRenameFeature(store: store),
                              ],
                              permissions: SystemPermissions(),
                              tapFactory: SystemEventTapFactory())
    }

    /// Called once at launch: applies saved switches and follows later
    /// Accessibility grants without polling.
    func activate() {
        accessibilityObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.accessibility.api"), object: nil, queue: .main
        ) { [weak self] _ in
            // The trust flag flips a moment after the notification.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self?.apply() }
        }
        apply()
    }

    deinit {
        if let accessibilityObserver { DistributedNotificationCenter.default().removeObserver(accessibilityObserver) }
        tap?.invalidate()
    }

    // MARK: Switches

    var masterEnabled: Bool {
        get { store.masterEnabled }
        set {
            store.masterEnabled = newValue
            if newValue { requestMissingPermissions(for: features.filter { store.isEnabled($0.id) }) }
            apply()
        }
    }

    func isEnabled(_ id: String) -> Bool { store.isEnabled(id) }

    func setEnabled(_ id: String, _ enabled: Bool) {
        store.setEnabled(id, enabled)
        if enabled, store.masterEnabled, let feature = features.first(where: { $0.id == id }) {
            requestMissingPermissions(for: [feature])
        }
        apply()
    }

    func isRunning(_ id: String) -> Bool { runningIDs.contains(id) }

    func isGranted(_ permission: Permission) -> Bool { permissions.isGranted(permission) }

    func request(_ permission: Permission) { permissions.request(permission) }

    /// Permissions some switched-on feature needs.
    var neededPermissions: Set<Permission> {
        features.filter { store.isEnabled($0.id) }.reduce(into: Set()) { $0.formUnion($1.requiredPermissions) }
    }

    /// Settings edits that do not change a switch still refresh the UI.
    func update(_ change: (SettingsStore) -> Void) {
        change(store)
        objectWillChange.send()
    }

    private func requestMissingPermissions(for features: [Feature]) {
        let missing = features.reduce(into: Set<Permission>()) { $0.formUnion($1.requiredPermissions) }
            .filter { !permissions.isGranted($0) }
        for permission in Permission.allCases where missing.contains(permission) {
            permissions.request(permission)
        }
    }

    // MARK: Lifecycle

    /// Brings running features and the tap in line with the switches.
    /// Accessibility gates starting, since without it neither the tap nor the
    /// AX lookups work. Finder Automation is asked for lazily by the feature.
    func apply() {
        let trusted = permissions.isGranted(.accessibility)
        let wanted = Set(features.filter { feature in
            store.masterEnabled
                && store.isEnabled(feature.id)
                && (trusted || !feature.requiredPermissions.contains(.accessibility))
        }.map(\.id))

        for feature in features where runningIDs.contains(feature.id) && !wanted.contains(feature.id) {
            feature.stop()
            runningIDs.remove(feature.id)
        }
        for feature in features where wanted.contains(feature.id) && !runningIDs.contains(feature.id) {
            feature.start()
            runningIDs.insert(feature.id)
        }

        let mask = features.filter { runningIDs.contains($0.id) }.reduce(CGEventMask(0)) { $0 | $1.eventMask }
        if mask == 0 {
            tap?.invalidate()
            tap = nil
        } else if tap?.mask != mask {
            tap?.invalidate()
            tap = tapFactory.makeTap(mask: mask) { [weak self] type, event in
                self?.dispatch(type: type, event: event) ?? .pass
            }
        }
        objectWillChange.send()
    }

    func dispatch(type: CGEventType, event: CGEvent) -> TapResult {
        let bit = CGEventMask(1) << type.rawValue
        for feature in features where runningIDs.contains(feature.id) && feature.eventMask & bit != 0 {
            if feature.handle(type: type, event: event) == .consume { return .consume }
        }
        return .pass
    }
}
