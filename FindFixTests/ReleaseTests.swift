// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 FindFix contributors

import XCTest
@testable import FindFix

final class ReleaseTests: XCTestCase {
    private func json(tag: String = "v1.1",
                      draft: Bool = false,
                      prerelease: Bool = false,
                      assets: [String] = ["FindFix-1.1-arm64.dmg"]) -> Data {
        let list = assets.map {
            #"{"name":"\#($0)","browser_download_url":"https://github.com/j0di3x/FindFix/releases/download/\#(tag)/\#($0)"}"#
        }.joined(separator: ",")
        return Data(#"""
        {"tag_name":"\#(tag)","body":"Fixes the Delete key.","html_url":"https://github.com/j0di3x/FindFix/releases/tag/\#(tag)",
         "draft":\#(draft),"prerelease":\#(prerelease),"assets":[\#(list)]}
        """#.utf8)
    }

    func testParsesLatestRelease() throws {
        let release = try XCTUnwrap(Release(githubJSON: json()))
        XCTAssertEqual(release.version, "1.1")
        XCTAssertEqual(release.notes, "Fixes the Delete key.")
        XCTAssertEqual(release.dmgURL.lastPathComponent, "FindFix-1.1-arm64.dmg")
        XCTAssertEqual(release.pageURL.lastPathComponent, "v1.1")
    }

    func testPicksTheArmDMG() throws {
        let release = try XCTUnwrap(Release(githubJSON: json(assets: ["notes.txt", "FindFix-1.1-arm64.dmg"])))
        XCTAssertEqual(release.dmgURL.lastPathComponent, "FindFix-1.1-arm64.dmg")
    }

    func testIgnoresUnusableReleases() {
        XCTAssertNil(Release(githubJSON: json(assets: [])))
        XCTAssertNil(Release(githubJSON: json(draft: true)))
        XCTAssertNil(Release(githubJSON: json(prerelease: true)))
        XCTAssertNil(Release(githubJSON: Data("{\"message\":\"Not Found\"}".utf8)))
    }

    func testVersionOrder() {
        XCTAssertTrue(Release.isNewer("1.1", than: "1.0"))
        XCTAssertTrue(Release.isNewer("1.10", than: "1.9"))
        XCTAssertTrue(Release.isNewer("2.0", than: "1.9.9"))
        XCTAssertTrue(Release.isNewer("v1.0.1", than: "1.0"))
        XCTAssertFalse(Release.isNewer("1.0", than: "1.0.0"))
        XCTAssertFalse(Release.isNewer("1.0", than: "1.1"))
    }

    func testUpdateSettingsPersist() {
        let defaults = makeTestDefaults()
        let store = SettingsStore(defaults: defaults)
        XCTAssertTrue(store.autoCheckUpdates)
        XCTAssertNil(store.skippedVersion)
        store.autoCheckUpdates = false
        store.skippedVersion = "1.1"

        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertFalse(reloaded.autoCheckUpdates)
        XCTAssertEqual(reloaded.skippedVersion, "1.1")
    }
}
