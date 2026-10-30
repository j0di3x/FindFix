// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 FindFix contributors

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var manager: FeatureManager
    @ObservedObject var updater: Updater
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            form
            Divider()
            HStack {
                Text("FindFix keeps running in the menu bar.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Done", action: onDone)
                    .keyboardShortcut("w")
                    .buttonStyle(.borderedProminent)
            }
            .padding(12)
        }
        .frame(width: 500, height: 660)
        .environment(\.layoutDirection, Self.layoutDirection)
        // Back from System Settings: pick up a new grant even if the system
        // never announced it.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            manager.apply()
        }
    }

    /// Follows the language FindFix actually runs in, so Arabic mirrors.
    private static var layoutDirection: LayoutDirection {
        let language = Locale.Language(identifier: Bundle.main.preferredLocalizations.first ?? "en")
        return language.characterDirection == .rightToLeft ? .rightToLeft : .leftToRight
    }

    private var form: some View {
        Form {
            Section {
                Toggle("Enable FindFix", isOn: Binding(get: { manager.masterEnabled },
                                                       set: { manager.masterEnabled = $0 }))
                Text("Turning this off restores every stock macOS behavior at once.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                Toggle("Open at login", isOn: Binding(get: { LoginItem.isEnabled },
                                                      set: { LoginItem.setEnabled($0); manager.objectWillChange.send() }))
                if LoginItem.needsApproval {
                    Text("Allow FindFix under System Settings › General › Login Items.")
                        .font(.caption).foregroundStyle(.orange)
                }
            }

            Section("Permissions") {
                PermissionRow(title: "Accessibility", permission: .accessibility, manager: manager)
                PermissionRow(title: "Automation (Finder)", permission: .automation, manager: manager)
            }

            ForEach(manager.features, id: \.id) { feature in
                Section {
                    featureToggle(feature)
                    options(for: feature)
                }
            }

            Section("Updates") {
                Toggle("Check for updates automatically", isOn: Binding(get: { updater.autoCheck },
                                                                         set: { updater.autoCheck = $0 }))
                LabeledContent {
                    Button("Check Now") { updater.check(userInitiated: true) }
                        .disabled(updater.state == .checking || updater.state == .installing)
                } label: {
                    Text(updater.stateMessage)
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("About") {
                LegalNotice()
            }
        }
        .formStyle(.grouped)
    }

    private func featureToggle(_ feature: Feature) -> some View {
        Toggle(isOn: Binding(get: { manager.isEnabled(feature.id) },
                             set: { manager.setEnabled(feature.id, $0) })) {
            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                Text(feature.summary).font(.caption).foregroundStyle(.secondary)
                if manager.isEnabled(feature.id), manager.masterEnabled, !manager.isRunning(feature.id) {
                    Text("Waiting for Accessibility permission.").font(.caption).foregroundStyle(.orange)
                }
            }
        }
    }

    @ViewBuilder
    private func options(for feature: Feature) -> some View {
        switch feature {
        case is QuitOnCloseFeature:
            ExclusionList(manager: manager)
        case is FinderDeleteKeyFeature:
            Toggle(isOn: Binding(get: { manager.store.permanentDelete },
                                 set: { newValue in
                                     manager.update { $0.permanentDelete = newValue }
                                     if newValue, !manager.isGranted(.automation) { manager.request(.automation) }
                                 })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Delete immediately (skip Trash)")
                    Text("Asks for confirmation every time. Can’t be undone.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.leading, 16)
        case is FinderRenameFeature:
            LabeledContent("Shortcut") {
                ShortcutRecorder(shortcut: Binding(get: { manager.store.renameShortcut },
                                                   set: { newValue in manager.update { $0.renameShortcut = newValue } }))
            }
            .padding(.leading, 16)
        default:
            EmptyView()
        }
    }
}

private struct PermissionRow: View {
    let title: LocalizedStringKey
    let permission: Permission
    @ObservedObject var manager: FeatureManager

    var body: some View {
        let granted = manager.isGranted(permission)
        let needed = manager.neededPermissions.contains(permission)
        LabeledContent {
            if !granted {
                HStack {
                    if permission == .accessibility {
                        Button("Reset") { SystemPermissions.resetAccessibility() }
                            .help("Use when FindFix is switched on in System Settings but still shows Needed.")
                    }
                    Button("Grant…") {
                        manager.request(permission)
                        if permission == .accessibility { SystemPermissions.openSettings(.accessibility) }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle")
                    .foregroundStyle(granted ? .green : (needed ? .orange : .secondary))
                Text(title)
                Text(granted ? "Granted" : (needed ? "Needed" : "Not needed yet"))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct ExclusionList: View {
    @ObservedObject var manager: FeatureManager
    @State private var selection: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Never quit these apps").font(.caption).foregroundStyle(.secondary)
            List(manager.store.quitExclusions, id: \.self, selection: $selection) { bundleID in
                Text(Self.displayName(bundleID))
            }
            .frame(height: 90)
            HStack {
                Button("Add App…", action: addApp)
                Button("Remove") {
                    guard let selection else { return }
                    manager.update { $0.quitExclusions.removeAll { $0 == selection } }
                    self.selection = nil
                }
                .disabled(selection == nil)
                Spacer()
                Button("Reset") {
                    manager.update { $0.quitExclusions = SettingsStore.defaultQuitExclusions }
                }
            }
        }
        .padding(.leading, 16)
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        let ids = panel.urls.compactMap { Bundle(url: $0)?.bundleIdentifier }
        manager.update { $0.quitExclusions += ids }
    }

    private static func displayName(_ bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return bundleID }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }
}
