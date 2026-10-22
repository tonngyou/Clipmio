// Copyright (c) 2026 tonngyou. MIT License.
import Foundation

enum AppPaths {
    static var historyFile: URL {
        var directory = FileManager.default.urls(for: .applicationSupportDirectory,
                                                 in: .userDomainMask)[0]
            .appendingPathComponent("Clipmio", isDirectory: true)
        #if DEBUG
        directory.appendPathComponent("Development", isDirectory: true)
        #endif
        return directory.appendingPathComponent("history.json")
    }
}

@MainActor
enum L10n {
    static func text(_ key: String) -> String {
        text(key, language: AppSettings.shared.language)
    }

    static func text(_ key: String, language: AppLanguage) -> String {
        let resources = ClipmioTheme.resourceBundle
        guard let path = resources.path(forResource: language.localizationIdentifier, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return key }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
}
