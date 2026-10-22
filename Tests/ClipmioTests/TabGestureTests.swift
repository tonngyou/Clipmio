import AppKit
import XCTest
@testable import Clipmio

final class TabGestureTests: XCTestCase {
    func testMouseDragSelectsAdjacentTabInEitherDirection() {
        XCTAssertEqual(HistoryTab.dragOffset(x: -80, y: 10), 1)
        XCTAssertEqual(HistoryTab.dragOffset(x: 80, y: -10), -1)
    }

    func testClickJitterAndVerticalMouseDragDoNotSelectTabs() {
        XCTAssertNil(HistoryTab.dragOffset(x: 20, y: 0))
        XCTAssertNil(HistoryTab.dragOffset(x: 60, y: 80))
        XCTAssertNil(HistoryTab.dragOffset(x: 60, y: 50))
    }

    func testHorizontalGestureCrossesThresholdOnceAndIgnoresMomentum() {
        var tracker = TabScrollTracker()
        XCTAssertNil(tracker.scroll(x: -12, y: 1, precise: true, phase: .began, timestamp: 1).offset)
        XCTAssertNil(tracker.scroll(x: -15, y: 0, precise: true, phase: .changed, timestamp: 1.01).offset)
        XCTAssertEqual(tracker.scroll(x: -14, y: 1, precise: true, phase: .changed, timestamp: 1.02).offset, 1)
        XCTAssertNil(tracker.scroll(x: -100, y: 0, precise: true, phase: .changed, timestamp: 1.03).offset)
        XCTAssertNil(tracker.scroll(x: 100, y: 0, precise: true, phase: .changed, timestamp: 1.04).offset)
        XCTAssertEqual(tracker.scroll(x: -200, y: 0, precise: true, momentum: .changed, timestamp: 1.05),
                       TabScrollTracker.Result(consumed: true))
        XCTAssertEqual(tracker.scroll(x: 50, y: 0, precise: true, phase: .began, timestamp: 1.2).offset, -1)
    }

    func testVerticalScrollAndItsHorizontalNoisePassThrough() {
        var tracker = TabScrollTracker()
        XCTAssertEqual(tracker.scroll(x: 2, y: -10, precise: true, phase: .began, timestamp: 1), .init())
        XCTAssertEqual(tracker.scroll(x: -80, y: -20, precise: true, phase: .changed, timestamp: 1.01), .init())
        XCTAssertEqual(tracker.scroll(x: -100, y: 0, precise: true, momentum: .changed, timestamp: 1.02), .init())
    }

    func testDiagonalGestureDoesNotNavigateWithoutClearHorizontalIntent() {
        var tracker = TabScrollTracker()
        XCTAssertEqual(tracker.scroll(x: -20, y: 18, precise: true, phase: .began, timestamp: 1), .init())
        XCTAssertEqual(tracker.scroll(x: -20, y: 18, precise: true, phase: .changed, timestamp: 1.01), .init())
    }

    func testWheelWithoutPhasesGroupsTicksAndResetsAfterIdle() {
        var tracker = TabScrollTracker()
        XCTAssertNil(tracker.scroll(x: -4, y: 0, precise: false, timestamp: 1).offset)
        XCTAssertEqual(tracker.scroll(x: -4, y: 0, precise: false, timestamp: 1.01).offset, 1)
        XCTAssertNil(tracker.scroll(x: -8, y: 0, precise: false, timestamp: 1.1).offset)
        XCTAssertEqual(tracker.scroll(x: 8, y: 0, precise: false, timestamp: 1.5).offset, -1)
    }

    func testCancelledAndEndedGesturesNeverSelectAnotherTab() {
        var tracker = TabScrollTracker()
        XCTAssertNil(tracker.scroll(x: -10, y: 0, precise: true, phase: .began, timestamp: 1).offset)
        XCTAssertNil(tracker.scroll(x: -100, y: 0, precise: true, phase: .cancelled, timestamp: 1.01).offset)
        XCTAssertNil(tracker.scroll(x: -100, y: 0, precise: true, phase: .ended, timestamp: 1.02).offset)
        XCTAssertEqual(tracker.scroll(x: 50, y: 0, precise: true, phase: .began, timestamp: 1.2).offset, -1)
    }

    func testDiscreteSwipeDoesNotDuplicateScrollNavigation() {
        var tracker = TabScrollTracker()
        XCTAssertEqual(tracker.scroll(x: -50, y: 0, precise: true, phase: .began, timestamp: 1).offset, 1)
        XCTAssertNil(tracker.swipe(x: -1, y: 0, timestamp: 1.01))
        XCTAssertNil(tracker.swipe(x: 0, y: 1, timestamp: 1.5))
        XCTAssertEqual(tracker.swipe(x: 1, y: 0, timestamp: 1.5), -1)
    }

    func testTabsStopAtBothEndsRatherThanWrap() {
        XCTAssertNil(HistoryTab.all.neighbor(by: -1))
        XCTAssertEqual(HistoryTab.all.neighbor(by: 1), .favorites)
        XCTAssertEqual(HistoryTab.favorites.neighbor(by: -1), .all)
        XCTAssertNil(HistoryTab.favorites.neighbor(by: 1))
    }
}
