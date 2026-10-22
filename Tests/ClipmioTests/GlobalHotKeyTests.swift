import AppKit
import Carbon.HIToolbox
import XCTest
@testable import Clipmio

final class GlobalHotKeyTests: XCTestCase {
    @MainActor
    func testChangingShortcutReleasesOldCombinationAndConflictKeepsWorkingShortcut() throws {
        let hotKey = makeHotKey()
        let oldCombination = makeHotKey()
        let alternative = KeyboardShortcut(keyCode: UInt32(kVK_F18), modifiers: UInt32(cmdKey | controlKey | optionKey | shiftKey))
        let owner = GlobalHotKey(shortcut: alternative)
        defer { hotKey.stop(); oldCombination.stop(); owner.stop() }
        try register(hotKey)
        try register(owner)
        XCTAssertFalse(hotKey.setShortcut(alternative))
        XCTAssertTrue(hotKey.isRegistered)
        XCTAssertEqual(hotKey.shortcut, oldCombination.shortcut)
        XCTAssertNil(hotKey.registrationError)
        XCTAssertFalse(oldCombination.start())
        owner.stop()
        XCTAssertTrue(hotKey.setShortcut(alternative))
        XCTAssertEqual(hotKey.shortcut, alternative)
        XCTAssertTrue(oldCombination.start())
        XCTAssertTrue(hotKey.start())
        var calls = 0
        hotKey.onTrigger = { calls += 1 }
        try send(identifier: hotKey.eventID, kind: UInt32(kEventHotKeyPressed))
        XCTAssertEqual(calls, 1)
    }

    @MainActor
    func testRecordingCancellationAndFailedReplacementCanRestoreOldRegistration() throws {
        let hotKey = makeHotKey()
        let original = hotKey.shortcut
        let occupied = KeyboardShortcut(keyCode: UInt32(kVK_F18), modifiers: UInt32(cmdKey | controlKey | optionKey | shiftKey))
        let owner = GlobalHotKey(shortcut: occupied)
        defer { hotKey.stop(); owner.stop() }
        try register(hotKey)
        try register(owner)
        hotKey.stop()
        XCTAssertFalse(hotKey.setShortcut(occupied))
        XCTAssertEqual(hotKey.shortcut, original)
        XCTAssertTrue(hotKey.start())
        XCTAssertTrue(hotKey.isRegistered)
        XCTAssertFalse(hotKey.setShortcut(KeyboardShortcut(keyCode: 9, modifiers: UInt32(shiftKey))))
        XCTAssertTrue(hotKey.isRegistered)
        XCTAssertEqual(hotKey.shortcut, original)
    }

    @MainActor
    private func makeHotKey() -> GlobalHotKey {
        // Avoid taking the user's actual shortcut during automated tests.
        GlobalHotKey(keyCode: UInt32(kVK_F19),
                     modifiers: UInt32(cmdKey | controlKey | optionKey | shiftKey))
    }

    @MainActor
    private func register(_ hotKey: GlobalHotKey) throws {
        _ = NSApplication.shared
        guard hotKey.start() else {
            throw XCTSkip("The isolated test shortcut could not be registered: \(hotKey.registrationError ?? 0)")
        }
    }

    @MainActor
    func testStartIsIdempotentAndStopReleasesTheShortcut() throws {
        let first = makeHotKey()
        let second = makeHotKey()
        defer { first.stop(); second.stop() }
        try register(first)
        XCTAssertTrue(first.isRegistered)
        XCTAssertTrue(first.start())
        XCTAssertNil(first.registrationError)
        first.stop()
        XCTAssertFalse(first.isRegistered)
        XCTAssertTrue(second.start())
    }

    @MainActor
    func testOccupiedShortcutCanBeRetriedWithoutAStaleHandler() throws {
        let owner = makeHotKey()
        let contender = makeHotKey()
        defer { owner.stop(); contender.stop() }
        try register(owner)
        XCTAssertFalse(contender.start())
        XCTAssertFalse(contender.isRegistered)
        XCTAssertNotNil(contender.registrationError)
        XCTAssertTrue(owner.isRegistered)
        owner.stop()
        XCTAssertTrue(contender.start())
        XCTAssertTrue(contender.isRegistered)
        XCTAssertNil(contender.registrationError)
    }

    @MainActor
    func testOnlyMatchingPressedEventInvokesTheCallback() throws {
        let hotKey = makeHotKey()
        defer { hotKey.stop() }
        try register(hotKey)
        var triggerCount = 0
        hotKey.onTrigger = { triggerCount += 1 }

        var otherID = hotKey.eventID
        otherID.id &+= 1
        try send(identifier: otherID, kind: UInt32(kEventHotKeyPressed))
        try send(identifier: hotKey.eventID, kind: UInt32(kEventHotKeyReleased))
        XCTAssertEqual(triggerCount, 0)
        try send(identifier: hotKey.eventID, kind: UInt32(kEventHotKeyPressed))
        XCTAssertEqual(triggerCount, 1)
        hotKey.stop()
        try send(identifier: hotKey.eventID, kind: UInt32(kEventHotKeyPressed))
        XCTAssertEqual(triggerCount, 1)
    }

    @MainActor
    private func send(identifier: EventHotKeyID, kind: UInt32) throws {
        var event: EventRef?
        let status = CreateEvent(nil, OSType(kEventClassKeyboard), kind,
                                 GetCurrentEventTime(), EventAttributes(kEventAttributeNone), &event)
        XCTAssertEqual(status, noErr)
        let eventRef = try XCTUnwrap(event)
        defer { ReleaseEvent(eventRef) }
        var identifier = identifier
        XCTAssertEqual(SetEventParameter(eventRef, EventParamName(kEventParamDirectObject),
                                         EventParamType(typeEventHotKeyID),
                                         MemoryLayout<EventHotKeyID>.size, &identifier), noErr)
        _ = SendEventToEventTarget(eventRef, GetApplicationEventTarget())
    }
}
