import AppKit
import Carbon.HIToolbox
import SwiftUI
import XCTest
@testable import Clipmio

final class PreviewKeyboardTests: XCTestCase {
    @MainActor
    func testSpaceOpensSelectionWhenSearchIsEmpty() {
        var previews = 0
        let field = HistorySearchField(text: .constant(""), onMove: { _ in }, onSubmit: {}, onEscape: {},
                                       onPreview: { previews += 1 })
        let coordinator = field.makeCoordinator()
        XCTAssertTrue(coordinator.handleSpace(searchText: "", composing: false, modifiers: [], isRepeat: false))
        XCTAssertEqual(previews, 1)
        XCTAssertTrue(coordinator.handleSpace(searchText: "", composing: false, modifiers: [], isRepeat: true))
        XCTAssertEqual(previews, 1)
    }

    @MainActor
    func testTypingSpacesInSearchRemainsTextEditingUntilNavigating() {
        var previews = 0
        let field = HistorySearchField(text: .constant("hello"), onMove: { _ in }, onSubmit: {}, onEscape: {},
                                       onPreview: { previews += 1 })
        let coordinator = field.makeCoordinator()
        XCTAssertFalse(coordinator.handleSpace(searchText: "hello", composing: false, modifiers: [], isRepeat: false))
        XCTAssertEqual(previews, 0)
        coordinator.parent.isNavigatingHistory = true
        XCTAssertTrue(coordinator.handleSpace(searchText: "hello", composing: false, modifiers: [], isRepeat: false))
        XCTAssertEqual(previews, 1)
    }

    @MainActor
    func testIMEAndModifiedSpacesAreNotIntercepted() {
        var previews = 0
        let field = HistorySearchField(text: .constant(""), onMove: { _ in }, onSubmit: {}, onEscape: {},
                                       onPreview: { previews += 1 }, isNavigatingHistory: true)
        let coordinator = field.makeCoordinator()
        XCTAssertFalse(coordinator.handleSpace(searchText: "", composing: true, modifiers: [], isRepeat: false))
        for modifier: NSEvent.ModifierFlags in [.command, .control, .option, .shift] {
            XCTAssertFalse(coordinator.handleSpace(searchText: "", composing: false, modifiers: modifier, isRepeat: false))
        }
        XCTAssertEqual(previews, 0)
    }

    @MainActor
    func testSpaceWithoutAnAvailableSelectionDoesNotOpenAnything() {
        let field = HistorySearchField(text: .constant(""), onMove: { _ in }, onSubmit: {}, onEscape: {})
        XCTAssertFalse(field.makeCoordinator().handleSpace(searchText: "", composing: false,
                                                          modifiers: [], isRepeat: false))
    }

    @MainActor
    func testPreviewSpaceAndEscapeCloseWithoutPasting() {
        var closes = 0
        var pastes = 0
        let actions = PreviewKeyboardActions(close: { closes += 1 }, paste: { pastes += 1 })
        XCTAssertTrue(actions.handle(keyCode: UInt16(kVK_Space), modifiers: [], isRepeat: false, composing: false))
        XCTAssertTrue(actions.handle(keyCode: UInt16(kVK_Escape), modifiers: [], isRepeat: false, composing: false))
        XCTAssertTrue(actions.handle(keyCode: UInt16(kVK_Space), modifiers: [], isRepeat: true, composing: false))
        XCTAssertEqual(closes, 2)
        XCTAssertEqual(pastes, 0)
    }

    @MainActor
    func testPreviewReturnPastesAndOtherEditingKeysPassThrough() {
        var pastes = 0
        let actions = PreviewKeyboardActions(close: {}, paste: { pastes += 1 })
        for key in [kVK_Return, kVK_ANSI_KeypadEnter] {
            XCTAssertTrue(actions.handle(keyCode: UInt16(key), modifiers: [], isRepeat: false, composing: false))
        }
        XCTAssertEqual(pastes, 2)
        XCTAssertTrue(actions.handle(keyCode: UInt16(kVK_Return), modifiers: [], isRepeat: true, composing: false))
        XCTAssertEqual(pastes, 2)
        XCTAssertFalse(actions.handle(keyCode: UInt16(kVK_ANSI_C), modifiers: .command, isRepeat: false, composing: false))
        XCTAssertFalse(actions.handle(keyCode: UInt16(kVK_DownArrow), modifiers: [], isRepeat: false, composing: false))
        XCTAssertFalse(actions.handle(keyCode: UInt16(kVK_Space), modifiers: .control, isRepeat: false, composing: false))
        XCTAssertFalse(actions.handle(keyCode: UInt16(kVK_Space), modifiers: [], isRepeat: false, composing: true))
    }
}
