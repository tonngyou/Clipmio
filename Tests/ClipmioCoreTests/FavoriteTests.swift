import Foundation
import XCTest
@testable import ClipmioCore

final class FavoriteTests: XCTestCase {
    @MainActor
    func testFavoritesSurviveEvictionRecopyClearAndReload() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("history.json")
        let store = HistoryStore(fileURL: file, limit: 2)
        store.capture("Keep 中文", sourceName: "Notes", sourceBundleID: "com.apple.Notes")
        let id = try XCTUnwrap(store.entries.first?.id)
        XCTAssertTrue(store.setFavorite(true, id: id))
        for i in 0..<20 { store.capture("recent \(i)") }
        XCTAssertEqual(store.entries.count, 3)
        XCTAssertEqual(store.entries.last?.id, id)
        XCTAssertEqual(store.matching("notes", favoritesOnly: true).map(\.id), [id])
        XCTAssertTrue(store.matching("recent", favoritesOnly: true).isEmpty)
        store.capture("Keep 中文", sourceName: "Safari", sourceBundleID: "com.apple.Safari")
        XCTAssertEqual(store.entries.first?.id, id)
        XCTAssertEqual(store.entries.first?.isFavorite, true)
        XCTAssertEqual(store.entries.first?.sourceBundleID, "com.apple.Safari")
        store.clear(keepingFavorites: true)
        let loaded = HistoryStore(fileURL: file, limit: 2)
        XCTAssertEqual(loaded.entries, store.entries)
        XCTAssertEqual(loaded.entries.map(\.id), [id])
        loaded.remove(id: id)
        XCTAssertTrue(HistoryStore(fileURL: file).entries.isEmpty)
    }

    @MainActor
    func testFavoriteLimitAndUnfavoriteNeverPreventNewCaptures() throws {
        let store = HistoryStore(limit: 2, favoriteLimit: 1)
        store.capture("favorite")
        let first = store.entries[0].id
        XCTAssertTrue(store.setFavorite(true, id: first))
        store.capture("another")
        let second = store.entries[0].id
        XCTAssertFalse(store.canAddFavorite)
        XCTAssertFalse(store.setFavorite(true, id: second))
        XCTAssertTrue(store.setFavorite(true, id: first))
        store.capture("newest")
        XCTAssertEqual(store.entries.map(\.text), ["newest", "another", "favorite"])
        XCTAssertTrue(store.setFavorite(false, id: first))
        XCTAssertTrue(store.canAddFavorite)
        XCTAssertEqual(store.entries.map(\.text), ["newest", "another"])
        XCTAssertFalse(store.setFavorite(true, id: UUID()))
    }

    @MainActor
    func testLegacyHistoryWithoutNewFieldsMigratesWithoutLosingTextOrIdentity() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("history.json")
        let original = ClipEntry(text: "legacy\n完整内容", sourceName: "Notes")
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode([original])) as? [[String: Any]])
        json[0].removeValue(forKey: "isFavorite")
        json[0].removeValue(forKey: "sourceBundleID")
        try JSONSerialization.data(withJSONObject: json).write(to: file)
        let store = HistoryStore(fileURL: file)
        XCTAssertNil(store.storageIssue)
        XCTAssertEqual(store.entries, [original])
        XCTAssertTrue(store.setFavorite(true, id: original.id))
        XCTAssertEqual(HistoryStore(fileURL: file).entries.first?.isFavorite, true)
    }
}
