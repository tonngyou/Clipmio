import Foundation
import XCTest
@testable import ClipmioCore

final class HistorySelectionTests: XCTestCase {
    func testArrowSelectionStopsAtBothEnds() {
        let ids = (0..<3).map { _ in UUID() }
        var selection = HistorySelection()
        selection.reconcile(with: ids)
        XCTAssertEqual(selection.selectedID, ids[0])
        selection.move(by: -1, in: ids)
        XCTAssertEqual(selection.selectedID, ids[0])
        selection.move(by: 1, in: ids)
        XCTAssertEqual(selection.selectedID, ids[1])
        selection.move(by: 1, in: ids)
        selection.move(by: 1, in: ids)
        XCTAssertEqual(selection.selectedID, ids[2])
    }

    func testNewCopiesPreserveSelectionAndNewSearchResetsIt() {
        let ids = (0..<3).map { _ in UUID() }
        var selection = HistorySelection()
        selection.reconcile(with: ids)
        selection.move(by: 1, in: ids)
        selection.reconcile(with: [UUID()] + ids)
        XCTAssertEqual(selection.selectedID, ids[1])
        selection.reconcile(with: [ids[2], ids[1]], reset: true)
        XCTAssertEqual(selection.selectedID, ids[2])
    }

    func testRemovedSelectionAndEmptyResultsNeverLeaveAStaleID() {
        let ids = (0..<2).map { _ in UUID() }
        var selection = HistorySelection()
        selection.reconcile(with: ids)
        selection.reconcile(with: [ids[1]])
        XCTAssertEqual(selection.selectedID, ids[1])
        selection.reconcile(with: [])
        selection.move(by: 1, in: [])
        XCTAssertNil(selection.selectedID)
        selection.move(by: 1, in: ids)
        XCTAssertEqual(selection.selectedID, ids[0])
    }
    func testExplicitPreviewSelectionOnlyAcceptsVisibleRecords() {
        let ids = [UUID(), UUID(), UUID()]
        var selection = HistorySelection()
        selection.select(ids[2], in: ids)
        XCTAssertEqual(selection.selectedID, ids[2])
        selection.reconcile(with: ids)
        XCTAssertEqual(selection.selectedID, ids[2])
        selection.select(UUID(), in: ids)
        XCTAssertEqual(selection.selectedID, ids[0])
        selection.select(ids[0], in: [])
        XCTAssertNil(selection.selectedID)
    }

}
