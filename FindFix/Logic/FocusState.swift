// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 FindFix contributors

/// What has keyboard focus inside Finder, as Accessibility reports it.
enum FocusState: Equatable {
    case element(role: String, subrole: String?)
    /// Finder answered but nothing inside it has focus (the Desktop).
    case none
    /// Finder did not answer in time, or Accessibility failed.
    case unavailable

    static let textRoles: Set<String> = [
        "AXTextField", "AXTextArea", "AXComboBox", "AXSearchField", "AXSecureTextField", "AXWebArea",
    ]
    static let textSubroles: Set<String> = ["AXSearchField", "AXSecureTextField"]

    /// True when keys should go to text editing, or when we cannot tell:
    /// unknown focus is treated as text so FindFix never steals a keystroke
    /// that might be typing.
    var isTextInput: Bool {
        switch self {
        case let .element(role, subrole):
            return Self.textRoles.contains(role) || subrole.map(Self.textSubroles.contains) == true
        case .none:
            return false
        case .unavailable:
            return true
        }
    }
}
