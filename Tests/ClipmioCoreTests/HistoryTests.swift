import Foundation
import XCTest
@testable import ClipmioCore

final class HistoryTests: XCTestCase {
    @MainActor
    func testFullCapacityLongTextHistorySurvivesPersistenceAndFiltering() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("history.json")
        let store = HistoryStore(fileURL: file)
        let payload = String(repeating: "中é🙂\n", count: 20000)
        for index in 0..<55 {
            store.capture("record-\(index)\n" + payload + "\nunique-tail-\(index)", sourceName: "Regression")
        }
        XCTAssertEqual(store.entries.count, 50)
        XCTAssertEqual(Set(store.entries.map(\.id)).count, 50)
        XCTAssertEqual(store.entries.first?.text, "record-54\n" + payload + "\nunique-tail-54")
        XCTAssertTrue(store.entries.allSatisfy { $0.preview.count <= 400 })
        let loaded = HistoryStore(fileURL: file)
        XCTAssertNil(loaded.storageIssue)
        XCTAssertEqual(loaded.entries, store.entries)
        XCTAssertEqual(loaded.matching("unique-tail-54").count, 1)
        XCTAssertEqual(loaded.matching("no-such-record").count, 0)
        XCTAssertEqual(loaded.matching("REGRESSION").count, 50)
    }

    @MainActor
    func testLongUnicodePreviewIsBoundedWithoutTruncatingStoredOrSearchableText() {
        let fullText = String(repeating: "👨‍👩‍👧‍👦中文\n", count: 5000) + "unique-tail"
        let store = HistoryStore()
        store.capture(fullText)
        let entry = store.entries[0]
        XCTAssertLessThanOrEqual(entry.preview.count, 400)
        XCTAssertFalse(entry.preview.contains("\n"))
        XCTAssertTrue(entry.preview.hasPrefix("👨‍👩‍👧‍👦中文"))
        XCTAssertEqual(entry.text, fullText)
        XCTAssertEqual(store.matching("unique-tail").first?.text, fullText)
    }

    @MainActor
    func testRecopyMovesExactTextToFrontWithoutChangingItsIdentity() {
        let store = HistoryStore()
        store.capture("A", sourceName: "Notes", at: Date(timeIntervalSince1970: 1))
        let originalID = store.entries[0].id
        store.capture("B")
        store.capture("A", sourceName: "Safari", at: Date(timeIntervalSince1970: 3))
        XCTAssertEqual(store.entries.map(\.text), ["A", "B"])
        XCTAssertEqual(store.entries[0].id, originalID)
        XCTAssertEqual(store.entries[0].sourceName, "Safari")
        XCTAssertEqual(store.entries[0].copiedAt, Date(timeIntervalSince1970: 3))
    }

    @MainActor
    func testCapacityAndWhitespacePreservation() {
        let store = HistoryStore(limit: 2)
        store.capture("one")
        store.capture("two")
        store.capture("  three\n")
        XCTAssertEqual(store.entries.map(\.text), ["  three\n", "two"])
        store.capture(" \n\t")
        XCTAssertEqual(store.entries.count, 2)
    }

    @MainActor
    func testSearchMatchesChineseSourceAndCaseWithoutReordering() {
        let store = HistoryStore()
        store.capture("Hello WORLD", sourceName: "Safari")
        store.capture("复制过的，随时找回。", sourceName: "Notes")
        XCTAssertEqual(store.matching("world").map(\.text), ["Hello WORLD"])
        XCTAssertEqual(store.matching(" 找回 ").count, 1)
        XCTAssertEqual(store.matching("safari").count, 1)
        XCTAssertEqual(store.entries[0].sourceName, "Notes")
    }

    @MainActor
    func testPersistenceRoundTripAndFilePermissions() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("history.json")
        let store = HistoryStore(fileURL: file)
        store.capture("你好，Clipmio\n  preserve formatting", sourceName: "Notes")
        let loaded = HistoryStore(fileURL: file)
        XCTAssertEqual(loaded.entries, store.entries)
        XCTAssertNil(loaded.storageIssue)
        let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        store.clear()
        XCTAssertTrue(HistoryStore(fileURL: file).entries.isEmpty)
    }

    @MainActor
    func testCorruptHistoryIsNotSilentlyOverwritten() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("history.json")
        let original = Data("unreadable data".utf8)
        try original.write(to: file)
        let store = HistoryStore(fileURL: file)
        XCTAssertEqual(store.storageIssue, .unreadableHistory)
        store.capture("new entry")
        XCTAssertEqual(try Data(contentsOf: file), original)
        store.clear()
        XCTAssertNil(store.storageIssue)
        XCTAssertEqual(try JSONDecoder().decode([ClipEntry].self, from: Data(contentsOf: file)), [])
    }

    @MainActor
    func testDeletionSurvivesRestart() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("history.json")
        let store = HistoryStore(fileURL: file)
        store.capture("keep")
        store.capture("delete")
        store.remove(id: store.entries[0].id)
        XCTAssertEqual(HistoryStore(fileURL: file).entries.map(\.text), ["keep"])
    }

    func testSensitiveClipboardTypesAndPasswordManagersAreExcluded() {
        for type in CapturePolicy.privateTypes {
            XCTAssertFalse(CapturePolicy.allows(types: ["public.utf8-plain-text", type], sourceBundleIDs: []))
        }
        XCTAssertFalse(CapturePolicy.allows(types: [], sourceBundleIDs: ["com.bitwarden.desktop"]))
        XCTAssertTrue(CapturePolicy.allows(types: ["public.utf8-plain-text"], sourceBundleIDs: ["com.apple.Notes"]))
    }

    func testOversizedAndEmptyTextIsRejected() {
        XCTAssertFalse(CapturePolicy.accepts(text: "\n \t"))
        XCTAssertFalse(CapturePolicy.accepts(text: String(repeating: "中", count: 100_000)))
        XCTAssertTrue(CapturePolicy.accepts(text: "  keep these spaces\n"))
    }
}
