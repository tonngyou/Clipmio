// Copyright (c) 2026 tonngyou. MIT License.
import Foundation
import Observation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system, simplifiedChinese = "zh-Hans", traditionalChinese = "zh-Hant", english = "en"

    var id: String { rawValue }

    var localizationIdentifier: String {
        guard self == .system else { return rawValue }
        return Bundle.preferredLocalizations(from: ["en", "zh-Hans", "zh-Hant"],
                                              forPreferences: Locale.preferredLanguages).first ?? "en"
    }

    var locale: Locale { Locale(identifier: localizationIdentifier) }
}

@MainActor @Observable
final class AppSettings {
    // Demo interactions must not change the installed app's preferences.
    static let shared = AppSettings(defaults: ProcessInfo.processInfo.arguments.contains("--demo") ? nil : .standard)
    private let defaults: UserDefaults?
    static let languageKey = "interfaceLanguage"

    var language: AppLanguage {
        didSet { defaults?.set(language.rawValue, forKey: Self.languageKey) }
    }

    init(defaults: UserDefaults? = .standard) {
        self.defaults = defaults
        language = defaults?.string(forKey: Self.languageKey).flatMap(AppLanguage.init(rawValue:)) ?? .system
    }
}
