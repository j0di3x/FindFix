// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 FindFix contributors

import AppKit
import Security

/// Checks GitHub Releases for a newer FindFix and installs it in place: the
/// DMG is downloaded, its app checked, swapped in for the running one, and
/// FindFix relaunches. Automatic checks run at most once a day.
final class Updater: ObservableObject {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(Release)
        case installing
        case failed(String)
    }

    @Published private(set) var state = State.idle

    private let store: SettingsStore
    private var timer: Timer?
    private static let interval: TimeInterval = 24 * 60 * 60

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    init(store: SettingsStore) {
        self.store = store
    }

    var autoCheck: Bool {
        get { store.autoCheckUpdates }
        set {
            store.autoCheckUpdates = newValue
            objectWillChange.send()
            schedule()
        }
    }

    /// Called once at launch. A timer that fires once an hour, with wide
    /// tolerance, keeps idle cost at nothing while catching Macs that slept.
    func schedule() {
        timer?.invalidate()
        timer = nil
        guard store.autoCheckUpdates else { return }
        let timer = Timer(timeInterval: 60 * 60, repeats: true) { [weak self] _ in self?.checkIfDue() }
        timer.tolerance = 10 * 60
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in self?.checkIfDue() }
    }

    private func checkIfDue() {
        guard store.autoCheckUpdates, state != .checking, state != .installing else { return }
        if let last = store.lastUpdateCheck, Date().timeIntervalSince(last) < Self.interval { return }
        check(userInitiated: false)
    }

    /// `userInitiated` checks always report back; automatic ones speak up
    /// only for a new version the user has not skipped.
    func check(userInitiated: Bool) {
        guard state != .checking, state != .installing else { return }
        state = .checking
        var request = URLRequest(url: Release.latestURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("FindFix/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request) { data, response, error in
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let release = data.flatMap(Release.init(githubJSON:))
            DispatchQueue.main.async {
                self.finishCheck(release: release, ok: error == nil && status == 200, userInitiated: userInitiated)
            }
        }.resume()
    }

    private func finishCheck(release: Release?, ok: Bool, userInitiated: Bool) {
        guard ok else {
            state = .failed(String(localized: "Couldn’t reach GitHub."))
            if userInitiated { Self.inform(String(localized: "Couldn’t check for updates"), String(localized: "GitHub could not be reached. Try again later.")) }
            return
        }
        store.lastUpdateCheck = Date()
        guard let release, Release.isNewer(release.version, than: currentVersion) else {
            state = .upToDate
            if userInitiated { Self.inform(String(localized: "FindFix is up to date"), String(localized: "Version \(currentVersion) is the newest.")) }
            return
        }
        state = .available(release)
        if userInitiated || store.skippedVersion != release.version {
            offer(release, userInitiated: userInitiated)
        }
    }

    private func offer(_ release: Release, userInitiated: Bool) {
        let alert = NSAlert()
        alert.messageText = String(localized: "FindFix \(release.version) is available")
        let notes = release.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        alert.informativeText = String(localized: "You have \(currentVersion).")
            + (notes.isEmpty ? "" : "\n\n" + String(notes.prefix(800)))
        alert.addButton(withTitle: String(localized: "Install and Relaunch"))
        alert.addButton(withTitle: String(localized: "Later"))
        if !userInitiated { alert.addButton(withTitle: String(localized: "Skip This Version")) }
        NSApp.activate(ignoringOtherApps: true)
        switch alert.runModal() {
        case .alertFirstButtonReturn: install(release)
        case .alertThirdButtonReturn: store.skippedVersion = release.version
        default: break
        }
    }

    func install(_ release: Release) {
        guard state != .installing else { return }
        state = .installing
        let current = Bundle.main.bundleURL
        let currentVersion = currentVersion
        URLSession.shared.downloadTask(with: release.dmgURL) { location, response, error in
            let result = Result<URL, Error> {
                guard let location, error == nil, (response as? HTTPURLResponse)?.statusCode == 200 else {
                    throw UpdateError(String(localized: "The download failed."))
                }
                // The download is deleted when this handler returns.
                let dmg = FileManager.default.temporaryDirectory.appendingPathComponent("FindFix-\(UUID().uuidString).dmg")
                try FileManager.default.moveItem(at: location, to: dmg)
                defer { try? FileManager.default.removeItem(at: dmg) }
                return try Installer.install(dmg: dmg, replacing: current, newerThan: currentVersion)
            }
            DispatchQueue.main.async {
                switch result {
                case let .success(app):
                    Self.relaunch(app)
                case let .failure(error):
                    self.state = .failed((error as? UpdateError)?.message ?? error.localizedDescription)
                    self.offerManualDownload(release, reason: self.stateMessage)
                }
            }
        }.resume()
    }

    var stateMessage: String {
        switch state {
        case .idle: return String(localized: "Version \(currentVersion)")
        case .checking: return String(localized: "Checking…")
        case .upToDate: return String(localized: "FindFix is up to date.")
        case let .available(release): return String(localized: "Version \(release.version) is available.")
        case .installing: return String(localized: "Installing…")
        case let .failed(message): return message
        }
    }

    private func offerManualDownload(_ release: Release, reason: String) {
        let alert = NSAlert()
        alert.messageText = String(localized: "Couldn’t install the update")
        alert.informativeText = reason + "\n\n" + String(localized: "You can download FindFix \(release.version) and install it yourself.")
        alert.addButton(withTitle: String(localized: "Open Download Page"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn { NSWorkspace.shared.open(release.pageURL) }
    }

    /// Waits for this process to exit, then opens the new app.
    private static func relaunch(_ app: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "while /bin/kill -0 \"$1\" 2>/dev/null; do /bin/sleep 0.2; done; /usr/bin/open \"$0\"",
                             app.path, String(ProcessInfo.processInfo.processIdentifier)]
        try? process.run()
        NSApp.terminate(nil)
    }

    private static func inform(_ title: String, _ text: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

struct UpdateError: Error {
    let message: String
    init(_ message: String) { self.message = message }
}

/// The file work of an update, off the main thread.
private enum Installer {
    static func install(dmg: URL, replacing current: URL, newerThan currentVersion: String) throws -> URL {
        let fm = FileManager.default
        let mount = fm.temporaryDirectory.appendingPathComponent("FindFix-mount-\(UUID().uuidString)")
        try run("/usr/bin/hdiutil", "attach", dmg.path, "-nobrowse", "-readonly", "-noautoopen", "-mountpoint", mount.path)
        defer { try? run("/usr/bin/hdiutil", "detach", mount.path, "-force") }

        let newApp = mount.appendingPathComponent("FindFix.app")
        try verify(newApp, newerThan: currentVersion)

        // Stage next to the old app, so the swap is a rename on one volume.
        let staged = current.deletingLastPathComponent().appendingPathComponent(".FindFix-update.app")
        try? fm.removeItem(at: staged)
        do {
            try run("/usr/bin/ditto", newApp.path, staged.path)
        } catch {
            throw UpdateError(String(localized: "FindFix can’t write to \(current.deletingLastPathComponent().path). Move it to Applications first."))
        }
        do {
            return try fm.replaceItemAt(current, withItemAt: staged) ?? current
        } catch {
            try? fm.removeItem(at: staged)
            throw UpdateError(String(localized: "The new version couldn’t replace the old one: \(error.localizedDescription)"))
        }
    }

    /// The new app must be FindFix, newer, and intact: its code signature
    /// must be valid and carry FindFix's identifier. This catches a damaged
    /// or wrong download; the HTTPS download from GitHub vouches for origin.
    private static func verify(_ app: URL, newerThan currentVersion: String) throws {
        guard let bundle = Bundle(url: app),
              let bundleID = Bundle.main.bundleIdentifier,
              bundle.bundleIdentifier == bundleID,
              let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              Release.isNewer(version, than: currentVersion)
        else { throw UpdateError(String(localized: "The download doesn’t contain a newer FindFix.")) }

        var code: SecStaticCode?
        var requirement: SecRequirement?
        guard SecStaticCodeCreateWithPath(app as CFURL, [], &code) == errSecSuccess, let code,
              SecRequirementCreateWithString("identifier \"\(bundleID)\"" as CFString, [], &requirement) == errSecSuccess,
              SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate),
                                         requirement) == errSecSuccess
        else { throw UpdateError(String(localized: "The downloaded app failed its code signature check.")) }
    }

    private static func run(_ tool: String, _ arguments: String...) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw UpdateError(String(localized: "\(URL(fileURLWithPath: tool).lastPathComponent) failed (\(process.terminationStatus))."))
        }
    }
}
