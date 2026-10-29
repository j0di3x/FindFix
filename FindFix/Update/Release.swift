// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 FindFix contributors

import Foundation

/// A published FindFix release, read from GitHub's "latest release" answer.
/// Kept free of networking so it can be unit tested.
struct Release: Equatable {
    static let latestURL = URL(string: "https://api.github.com/repos/j0di3x/FindFix/releases/latest")!

    let version: String
    let notes: String
    let pageURL: URL
    let dmgURL: URL

    private struct Payload: Decodable {
        struct Asset: Decodable {
            let name: String
            let browser_download_url: URL
        }

        let tag_name: String
        let body: String?
        let html_url: URL
        let draft: Bool?
        let prerelease: Bool?
        let assets: [Asset]
    }

    /// Nil for drafts, pre-releases and releases without an arm64 DMG.
    init?(githubJSON data: Data) {
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data),
              payload.draft != true, payload.prerelease != true,
              let dmg = payload.assets.first(where: { $0.name.hasSuffix("-arm64.dmg") })
        else { return nil }
        version = payload.tag_name.hasPrefix("v") ? String(payload.tag_name.dropFirst()) : payload.tag_name
        notes = payload.body ?? ""
        pageURL = payload.html_url
        dmgURL = dmg.browser_download_url
    }

    /// Compares dotted versions numerically: 1.10 is newer than 1.9, and
    /// 1.0 equals 1.0.0.
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = components(candidate), b = components(current)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    private static func components(_ version: String) -> [Int] {
        let trimmed = version.hasPrefix("v") ? String(version.dropFirst()) : version
        return trimmed.split(separator: ".").map { Int($0.prefix { $0.isNumber }) ?? 0 }
    }
}
