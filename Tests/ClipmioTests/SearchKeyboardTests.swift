import AppKit
import SwiftUI
import XCTest
@testable import Clipmio

final class SearchKeyboardTests: XCTestCase {
    @MainActor
    func testEmptySearchRoutesLeftRightAndTheirTextSystemAliasesToTabs() {
        var tabs: [Int] = []
        let coordinator = HistorySearchField(text: .constant(""), onMove: { _ in XCTFail("Unexpected row move") },
            onSubmit: { XCTFail("Unexpected paste") }, onEscape: {}, onSwitchTab: { tabs.append($0) }).makeCoordinator()
        for command in [#selector(NSResponder.moveLeft(_:)), #selector(NSResponder.moveRight(_:)),
                        #selector(NSResponder.moveBackward(_:)), #selector(NSResponder.moveForward(_:))] {
            XCTAssertTrue(coordinator.handle(command: command, composing: false, modifiers: []))
        }
        XCTAssertEqual(tabs, [-1, 1, -1, 1])
    }

    @MainActor
    func testSearchEditingKeepsCursorArrowsUntilHistoryNavigationBegins() {
        var tabs: [Int] = []
        let coordinator = HistorySearchField(text: .constant("Notes"), onMove: { _ in }, onSubmit: {},
            onEscape: {}, onSwitchTab: { tabs.append($0) }).makeCoordinator()
        XCTAssertFalse(coordinator.handle(command: #selector(NSResponder.moveLeft(_:)), composing: false, modifiers: []))
        XCTAssertFalse(coordinator.handle(command: #selector(NSResponder.moveRight(_:)), composing: false, modifiers: []))
        coordinator.parent.isNavigatingHistory = true
        XCTAssertTrue(coordinator.handle(command: #selector(NSResponder.moveRight(_:)), composing: false, modifiers: []))
        XCTAssertTrue(coordinator.handle(command: #selector(NSResponder.moveLeft(_:)), composing: false, modifiers: []))
        XCTAssertEqual(tabs, [1, -1])
    }

    @MainActor
    func testTabArrowsRespectIMEEditingModifiersAndInactivePages() {
        var tabs: [Int] = []
        let coordinator = HistorySearchField(text: .constant(""), onMove: { _ in }, onSubmit: {},
            onEscape: {}, onSwitchTab: { tabs.append($0) }).makeCoordinator()
        for command in [#selector(NSResponder.moveLeft(_:)), #selector(NSResponder.moveRight(_:))] {
            XCTAssertFalse(coordinator.handle(command: command, composing: true, modifiers: []))
            for modifier: NSEvent.ModifierFlags in [.command, .option, .control, .shift] {
                XCTAssertFalse(coordinator.handle(command: command, composing: false, modifiers: modifier))
            }
        }
        coordinator.parent.isActive = { false }
        XCTAssertFalse(coordinator.handle(command: #selector(NSResponder.moveRight(_:)), composing: false, modifiers: []))
        XCTAssertTrue(tabs.isEmpty)
    }

    @MainActor
    func testLiveEditorTextTakesPrecedenceOverAnOutdatedSearchBinding() {
        var tabs: [Int] = []
        var boundText = ""
        let coordinator = HistorySearchField(text: Binding(get: { boundText }, set: { boundText = $0 }), onMove: { _ in }, onSubmit: {},
            onEscape: {}, onSwitchTab: { tabs.append($0) }).makeCoordinator()
        XCTAssertFalse(coordinator.handle(command: #selector(NSResponder.moveRight(_:)), composing: false,
                                          modifiers: [], searchText: "newly typed"))
        boundText = "stale binding"
        XCTAssertTrue(coordinator.handle(command: #selector(NSResponder.moveRight(_:)), composing: false,
                                         modifiers: [], searchText: ""))
        XCTAssertEqual(tabs, [1])
    }

    @MainActor
    func testArrowKeysAndReturnInvokeHistoryActions() {
        var moves: [Int] = []
        var submitted = 0
        var dismissed = 0
        let field = HistorySearchField(text: .constant(""), onMove: { moves.append($0) },
                                       onSubmit: { submitted += 1 }, onEscape: { dismissed += 1 })
        let coordinator = field.makeCoordinator()
        XCTAssertTrue(coordinator.handle(command: #selector(NSResponder.moveDown(_:)), composing: false, modifiers: []))
        XCTAssertTrue(coordinator.handle(command: #selector(NSResponder.moveUp(_:)), composing: false, modifiers: []))
        XCTAssertTrue(coordinator.handle(command: #selector(NSResponder.insertNewline(_:)), composing: false, modifiers: []))
        XCTAssertTrue(coordinator.handle(command: #selector(NSResponder.cancelOperation(_:)), composing: false, modifiers: []))
        XCTAssertEqual(moves, [1, -1])
        XCTAssertEqual(submitted, 1)
        XCTAssertEqual(dismissed, 1)
    }

    @MainActor
    func testIMECompositionKeepsArrowsAndReturnForCandidateSelection() {
        var intercepted = false
        let coordinator = HistorySearchField(text: .constant("中文"), onMove: { _ in intercepted = true },
                                             onSubmit: { intercepted = true }, onEscape: { intercepted = true })
            .makeCoordinator()
        for command in [#selector(NSResponder.moveDown(_:)), #selector(NSResponder.moveUp(_:)),
                        #selector(NSResponder.insertNewline(_:)), #selector(NSResponder.cancelOperation(_:))] {
            XCTAssertFalse(coordinator.handle(command: command, composing: true, modifiers: []))
        }
        XCTAssertFalse(intercepted)
    }

    @MainActor
    func testModifiedArrowsAndOrdinaryTextEditingAreNotIntercepted() {
        var intercepted = false
        let coordinator = HistorySearchField(text: .constant(""), onMove: { _ in intercepted = true },
                                             onSubmit: { intercepted = true }, onEscape: { intercepted = true })
            .makeCoordinator()
        for modifier: NSEvent.ModifierFlags in [.command, .option, .control, .shift] {
            XCTAssertFalse(coordinator.handle(command: #selector(NSResponder.moveDown(_:)),
                                              composing: false, modifiers: modifier))
        }
        XCTAssertFalse(coordinator.handle(command: #selector(NSResponder.moveLeft(_:)), composing: false, modifiers: []))
        XCTAssertFalse(intercepted)
    }
}
