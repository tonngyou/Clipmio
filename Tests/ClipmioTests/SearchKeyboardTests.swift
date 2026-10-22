import AppKit
import SwiftUI
import XCTest
@testable import Clipmio

final class SearchKeyboardTests: XCTestCase {
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
