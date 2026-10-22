import AppKit
import XCTest
import ClipmioCore
@testable import Clipmio

final class MonitorTests: XCTestCase {
    @MainActor
    func testOwnCopyDoesNotAddAnExtraHistoryEntry() {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let store = HistoryStore()
        let monitor = ClipboardMonitor(history: store, pasteboard: pasteboard)
        pasteboard.clearContents()
        XCTAssertTrue(pasteboard.setString("original", forType: .string))
        monitor.poll()
        XCTAssertEqual(store.entries.map(\.text), ["original"])
        XCTAssertTrue(monitor.copy("copied by Clipmio"))
        monitor.poll()
        XCTAssertEqual(store.entries.map(\.text), ["original"])
        XCTAssertEqual(pasteboard.string(forType: .string), "copied by Clipmio")
    }

    @MainActor
    func testPausedChangesAreNotCapturedAfterResume() {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let store = HistoryStore()
        let monitor = ClipboardMonitor(history: store, pasteboard: pasteboard)
        monitor.togglePause()
        pasteboard.clearContents()
        XCTAssertTrue(pasteboard.setString("while paused", forType: .string))
        monitor.togglePause()
        monitor.poll()
        XCTAssertTrue(store.entries.isEmpty)
        pasteboard.clearContents()
        XCTAssertTrue(pasteboard.setString("after resume", forType: .string))
        monitor.poll()
        XCTAssertEqual(store.entries.map(\.text), ["after resume"])
    }

    @MainActor
    func testPrivateMarkersAreExcludedOnTheActualPasteboard() {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let store = HistoryStore()
        let monitor = ClipboardMonitor(history: store, pasteboard: pasteboard)
        pasteboard.declareTypes([.string, .init("org.nspasteboard.ConcealedType")], owner: nil)
        pasteboard.setString("secret", forType: .string)
        pasteboard.setData(Data(), forType: .init("org.nspasteboard.ConcealedType"))
        monitor.poll()
        XCTAssertTrue(store.entries.isEmpty)
    }

    @MainActor
    func testClipboardContentFromBeforeStartupIsNotImported() {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        XCTAssertTrue(pasteboard.setString("before startup", forType: .string))
        let store = HistoryStore()
        let monitor = ClipboardMonitor(history: store, pasteboard: pasteboard)
        monitor.poll()
        XCTAssertTrue(store.entries.isEmpty)
    }
}
