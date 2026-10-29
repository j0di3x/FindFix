// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 FindFix contributors

import AppKit
import SwiftUI

/// The "Appropriate Legal Notices" GPL-3.0 section 5(d) asks an interactive
/// program to show: copyright, no warranty, the license and where the source is.
struct LegalNotice: View {
    static let sourceURL = URL(string: "https://github.com/j0di3x/FindFix")!
    static let upstreamURL = URL(string: "https://github.com/vorssaint/vorssaint-utils")!

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("FindFix \(version) · © 2026 j0di3x")
            Text("Includes code adapted from Vorssaint, © 2026 Vorssaint. FindFix is an unofficial project, not affiliated with or endorsed by Vorssaint.")
            Text("Free software under the GNU GPL v3 or later. It comes with ABSOLUTELY NO WARRANTY; you may redistribute it under the license’s conditions.")
            Text("Mac, macOS and Finder are trademarks of Apple Inc. FindFix is not affiliated with Apple.")
            HStack(spacing: 14) {
                Link("Source code", destination: Self.sourceURL)
                Button("License") { showLicense() }
                    .buttonStyle(.link)
                Link("Vorssaint source", destination: Self.upstreamURL)
            }
            .padding(.top, 2)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// The full license ships inside the app, as GPL section 4 requires.
    private func showLicense() {
        guard let url = Bundle.main.url(forResource: "LICENSE", withExtension: "txt") else { return }
        NSWorkspace.shared.open(url)
    }
}
