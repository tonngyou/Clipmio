import AppKit
import XCTest
@testable import Clipmio

final class SettingsTests: XCTestCase {
    @MainActor
    func testShortcutRecordingStopsWhenItsWindowLosesFocus() {
        _ = NSApplication.shared
        var changes: [Bool] = []
        let recorder = ShortcutRecorder(label: "⌘⇧V", onRecordingChange: { changes.append($0) },
                                        onCapture: { _ in XCTFail("Unexpected capture") }, onInvalid: {})
        let button = ShortcutRecorder.RecordingButton()
        button.parent = recorder
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 50),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = button
        NotificationCenter.default.addObserver(button, selector: #selector(ShortcutRecorder.RecordingButton.windowResignedKey(_:)),
                                               name: NSWindow.didResignKeyNotification, object: window)
        defer { NotificationCenter.default.removeObserver(button) }
        button.beginRecording()
        XCTAssertTrue(button.isRecording)
        NotificationCenter.default.post(name: NSWindow.didResignKeyNotification, object: window)
        XCTAssertFalse(button.isRecording)
        XCTAssertEqual(changes, [true, false])
    }

    @MainActor
    func testShortcutAndLayoutPersistAndInvalidShortcutFallsBack() throws {
        let name = "Clipmio.SettingsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults)
        XCTAssertTrue(settings.compactLayout)
        XCTAssertEqual(settings.shortcut, .default)
        settings.compactLayout = false
        let custom = KeyboardShortcut(keyCode: 8, modifiers: KeyboardShortcut.default.modifiers)
        settings.shortcut = custom
        XCTAssertEqual(AppSettings(defaults: defaults).shortcut, custom)
        XCTAssertFalse(AppSettings(defaults: defaults).compactLayout)
        defaults.set(try JSONEncoder().encode(KeyboardShortcut(keyCode: 9, modifiers: 0)), forKey: AppSettings.shortcutKey)
        XCTAssertEqual(AppSettings(defaults: defaults).shortcut, .default)
        defaults.set(Data("invalid".utf8), forKey: AppSettings.shortcutKey)
        XCTAssertEqual(AppSettings(defaults: defaults).shortcut, .default)
    }

    func testShortcutRejectsTypingOnlyAndModifierKeysAndNormalizesInputMethodFlags() throws {
        XCTAssertFalse(KeyboardShortcut(keyCode: 9, modifiers: 0).isValid)
        XCTAssertFalse(KeyboardShortcut(keyCode: 56, modifiers: KeyboardShortcut.default.modifiers).isValid)
        XCTAssertEqual(KeyboardShortcut.default.label, "⌘⇧V")
        let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero,
            modifierFlags: [.control, .option, .capsLock, .numericPad], timestamp: 0, windowNumber: 0,
            context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: 125))
        let value = KeyboardShortcut(event: event)
        XCTAssertTrue(value.isValid)
        XCTAssertEqual(value.label, "⌃⌥↓")
    }

    @MainActor
    func testLanguagePersistsAcrossSettingsInstancesAndInvalidValueFallsBack() throws {
        let name = "Clipmio.SettingsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.language, .system)
        settings.language = .english
        XCTAssertEqual(AppSettings(defaults: defaults).language, .english)
        settings.language = .simplifiedChinese
        XCTAssertEqual(AppSettings(defaults: defaults).language, .simplifiedChinese)
        defaults.set("unknown-language", forKey: AppSettings.languageKey)
        XCTAssertEqual(AppSettings(defaults: defaults).language, .system)
    }

    @MainActor
    func testExplicitLanguagesOverrideTheSystemAndTranslateSearchAndSettings() {
        XCTAssertEqual(L10n.text("Settings", language: .english), "Settings")
        XCTAssertEqual(L10n.text("Settings", language: .simplifiedChinese), "设置")
        XCTAssertEqual(L10n.text("Settings", language: .traditionalChinese), "設定")
        XCTAssertEqual(L10n.text("Search your copies…", language: .english), "Search your copies…")
        XCTAssertNotEqual(L10n.text("Search your copies…", language: .simplifiedChinese), "Search your copies…")
        XCTAssertEqual(L10n.text("An unknown key", language: .english), "An unknown key")
    }

    @MainActor
    func testAllLocalesContainTheSameTranslationKeys() throws {
        let bundle = ClipmioTheme.resourceBundle
        func translations(_ locale: String) throws -> [String: String] {
            let url = try XCTUnwrap(bundle.url(forResource: "Localizable", withExtension: "strings", subdirectory: "\(locale).lproj"))
            return try XCTUnwrap(PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: String])
        }
        let english = try translations("en")
        for locale in ["zh-Hans", "zh-Hant"] {
            XCTAssertEqual(Set(try translations(locale).keys), Set(english.keys))
        }
    }

    @MainActor
    func testLoginToggleReflectsRegistrationAndUnregistration() {
        let service = FakeLoginItemService()
        let manager = LoginItemManager(service: service, canManage: true)
        XCTAssertFalse(manager.state.isRequested)
        XCTAssertEqual(service.registrationCount, 0) // Opening settings must not opt in.
        manager.setEnabled(true)
        XCTAssertEqual(manager.state, .enabled)
        manager.setEnabled(true)
        XCTAssertEqual(service.registrationCount, 1)
        manager.setEnabled(false)
        XCTAssertEqual(manager.state, .disabled)
        XCTAssertEqual(service.unregistrationCount, 1)
    }

    @MainActor
    func testPendingApprovalCanBeCancelledAndExternalChangesAreRefreshed() {
        let service = FakeLoginItemService()
        service.registrationState = .requiresApproval
        let manager = LoginItemManager(service: service, canManage: true)
        manager.setEnabled(true)
        XCTAssertEqual(manager.state, .requiresApproval)
        XCTAssertTrue(manager.state.isRequested)
        manager.setEnabled(false)
        XCTAssertEqual(manager.state, .disabled)
        service.state = .enabled
        manager.refresh()
        XCTAssertEqual(manager.state, .enabled)
        service.state = .requiresApproval
        manager.refresh()
        XCTAssertEqual(manager.state, .requiresApproval)
    }

    @MainActor
    func testFailedChangeKeepsActualSystemState() {
        let service = FakeLoginItemService()
        let manager = LoginItemManager(service: service, canManage: true)
        service.shouldFail = true
        manager.setEnabled(true)
        XCTAssertEqual(manager.state, .disabled)
        XCTAssertTrue(manager.changeFailed)
        service.state = .enabled
        manager.setEnabled(false)
        XCTAssertEqual(manager.state, .enabled)
        XCTAssertTrue(manager.changeFailed)
        service.shouldFail = false
        manager.setEnabled(false)
        XCTAssertFalse(manager.changeFailed)
        XCTAssertEqual(manager.state, .disabled)
    }

    @MainActor
    func testPreviewAndUnbundledModeNeverChangeSystemLoginItems() {
        let service = FakeLoginItemService()
        let manager = LoginItemManager(service: service, canManage: false)
        manager.setEnabled(true)
        manager.setEnabled(false)
        manager.openSettings()
        XCTAssertEqual(manager.state, .unavailable)
        XCTAssertEqual(service.registrationCount, 0)
        XCTAssertEqual(service.unregistrationCount, 0)
        XCTAssertEqual(service.openSettingsCount, 0)
    }
}

@MainActor
private final class FakeLoginItemService: LoginItemService {
    var state: LoginItemState = .disabled
    var registrationState: LoginItemState = .enabled
    var shouldFail = false
    var registrationCount = 0
    var unregistrationCount = 0
    var openSettingsCount = 0
    func register() throws {
        registrationCount += 1
        if shouldFail { throw CocoaError(.fileWriteNoPermission) }
        state = registrationState
    }
    func unregister() throws {
        unregistrationCount += 1
        if shouldFail { throw CocoaError(.fileWriteNoPermission) }
        state = .disabled
    }
    func openSettings() { openSettingsCount += 1 }
}
