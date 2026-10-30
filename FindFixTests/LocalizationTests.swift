// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 FindFix contributors

import XCTest
@testable import FindFix

final class LocalizationTests: XCTestCase {
    private let languages = ["ar", "bn", "de", "es", "fr", "hi", "hu", "id", "pt-BR", "ru", "sk"]

    private func bundle(_ language: String) throws -> Bundle {
        let path = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"), language)
        return try XCTUnwrap(Bundle(path: path))
    }

    func testEveryLanguageShipsTranslations() throws {
        for language in languages {
            let translated = try bundle(language).localizedString(forKey: "Permissions", value: nil, table: nil)
            XCTAssertNotEqual(translated, "Permissions", language)
        }
    }

    func testSlovakPluralForms() throws {
        let format = try bundle("sk").localizedString(forKey: "Delete %lld items immediately?", value: nil, table: nil)
        let slovak = Locale(identifier: "sk")
        XCTAssertEqual(String(format: format, locale: slovak, 3), "Okamžite vymazať 3 položky?")
        XCTAssertEqual(String(format: format, locale: slovak, 7), "Okamžite vymazať 7 položiek?")
    }
}
