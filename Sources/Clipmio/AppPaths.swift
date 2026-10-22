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

enum L10n {
    static func text(_ key: String) -> String {
        #if SWIFT_PACKAGE
        Bundle.module.localizedString(forKey: key, value: key, table: nil)
        #else
        Bundle.main.localizedString(forKey: key, value: key, table: nil)
        #endif
    }
}
