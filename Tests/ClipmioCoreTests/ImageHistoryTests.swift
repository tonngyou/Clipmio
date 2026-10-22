import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import ClipmioCore

final class ImageHistoryTests: XCTestCase {
    @MainActor
    func testFavoriteImageAttachmentSurvivesEvictionAndCleanupUntilExplicitDeletion() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("history.json")
        let store = HistoryStore(fileURL: file, limit: 1)
        let data = try png()
        XCTAssertTrue(store.captureImage(data, sourceName: "Preview", sourceBundleID: "com.apple.Preview"))
        let id = try XCTUnwrap(store.entries.first?.id)
        XCTAssertTrue(store.setFavorite(true, id: id))
        for i in 0..<10 { store.capture("text \(i)") }
        XCTAssertTrue(store.captureImage(data, sourceName: "Notes", sourceBundleID: "com.apple.Notes"))
        XCTAssertEqual(store.entries.first?.id, id)
        XCTAssertEqual(store.entries.first?.isFavorite, true)
        store.clear(keepingFavorites: true)
        let loaded = HistoryStore(fileURL: file)
        let entry = try XCTUnwrap(loaded.entries.first)
        XCTAssertEqual(entry.sourceBundleID, "com.apple.Notes")
        XCTAssertEqual(loaded.imageData(for: entry), data)
        loaded.remove(id: id)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: folder.appendingPathComponent("Images").path).isEmpty)
    }

    @MainActor
    func testRepeatedMixedHistoryRolloverReloadAndClearNeverLeavesBrokenOrOrphanedImages() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("history.json")
        var store = HistoryStore(fileURL: file, limit: 12)
        for index in 0..<100 {
            if index.isMultiple(of: 3) {
                XCTAssertTrue(store.captureImage(try png(red: CGFloat(index % 10) / 10)))
            } else {
                store.capture("entry \(index)\n中文 🙂")
            }
            if index.isMultiple(of: 7), let id = store.entries.last?.id { store.remove(id: id) }
            if index.isMultiple(of: 13) {
                let expected = store.entries
                store = HistoryStore(fileURL: file, limit: 12)
                XCTAssertEqual(store.entries, expected)
            }
            XCTAssertLessThanOrEqual(store.entries.count, 12)
            XCTAssertNil(store.storageIssue)
            let images = store.entries.filter { $0.image != nil }
            for entry in images { XCTAssertNotNil(store.imageData(for: entry)) }
            let imageFolder = folder.appendingPathComponent("Images")
            let diskFiles = (try? FileManager.default.contentsOfDirectory(atPath: imageFolder.path)) ?? []
            XCTAssertEqual(Set(diskFiles), Set(images.compactMap { $0.image.map { $0.fingerprint + ".png" } }))
        }
        store.clear()
        XCTAssertTrue(HistoryStore(fileURL: file).entries.isEmpty)
        XCTAssertTrue(((try? FileManager.default.contentsOfDirectory(atPath: folder.appendingPathComponent("Images").path)) ?? []).isEmpty)
    }

    private func png(red: CGFloat = 0.6) throws -> Data {
        let context = try XCTUnwrap(CGContext(data: nil, width: 8, height: 6, bitsPerComponent: 8,
                                             bytesPerRow: 32, space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: red, green: 0.2, blue: 0.5, alpha: 0.75))
        context.fill(CGRect(x: 0, y: 0, width: 8, height: 6))
        let output = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try XCTUnwrap(context.makeImage()), nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return output as Data
    }

    @MainActor
    func testImagesSurviveRestartOutsideJSONWithPrivatePermissions() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("history.json")
        let store = HistoryStore(fileURL: file)
        let data = try png()
        XCTAssertTrue(store.captureImage(data, sourceName: "Preview"))
        let entry = try XCTUnwrap(store.entries.first)
        let image = try XCTUnwrap(entry.image)
        XCTAssertEqual(image.width, 8)
        XCTAssertEqual(image.height, 6)
        let asset = folder.appendingPathComponent("Images/\(image.fingerprint).png")
        XCTAssertEqual(try Data(contentsOf: asset), data)
        let json = try String(contentsOf: file, encoding: .utf8)
        XCTAssertFalse(json.contains(data.base64EncodedString()))
        XCTAssertEqual(HistoryStore(fileURL: file).entries, store.entries)
        XCTAssertEqual(HistoryStore(fileURL: file).imageData(for: entry), data)
        let attributes = try FileManager.default.attributesOfItem(atPath: asset.path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        let directoryAttributes = try FileManager.default.attributesOfItem(atPath: asset.deletingLastPathComponent().path)
        XCTAssertEqual((directoryAttributes[.posixPermissions] as? NSNumber)?.intValue, 0o700)
    }

    @MainActor
    func testLegacyTextHistoryLoadsAndCanBeMixedWithImages() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("history.json")
        let legacy = "[{\"id\":\"\(UUID().uuidString)\",\"text\":\"旧文字\\n保留空格  \",\"copiedAt\":0,\"sourceName\":\"Notes\"}]"
        try Data(legacy.utf8).write(to: file)
        let store = HistoryStore(fileURL: file)
        XCTAssertNil(store.storageIssue)
        XCTAssertEqual(store.entries.first?.text, "旧文字\n保留空格  ")
        XCTAssertNil(store.entries.first?.image)
        XCTAssertTrue(store.captureImage(try png(), sourceName: "截图工具"))
        XCTAssertEqual(store.entries.count, 2)
        XCTAssertEqual(store.matching("图片").count, 1)
        XCTAssertEqual(store.matching("image").count, 1)
        XCTAssertEqual(store.matching("截图").count, 1)
        XCTAssertEqual(HistoryStore(fileURL: file).entries, store.entries)
    }

    @MainActor
    func testRecopyPreservesImageIdentityAndMixedLimitCleansAttachments() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("history.json")
        let store = HistoryStore(fileURL: file, limit: 2)
        let data = try png()
        store.captureImage(data)
        let imageID = try XCTUnwrap(store.entries.first?.id)
        store.capture("middle")
        store.captureImage(data, sourceName: "Preview")
        XCTAssertEqual(store.entries.first?.id, imageID)
        XCTAssertEqual(store.entries.count, 2)
        XCTAssertEqual(store.entries.first?.sourceName, "Preview")
        store.capture("new text")
        store.captureImage(try png(red: 0.1))
        XCTAssertFalse(store.entries.contains { $0.id == imageID })
        let images = try FileManager.default.contentsOfDirectory(atPath: folder.appendingPathComponent("Images").path)
        XCTAssertEqual(images.count, 1)
        XCTAssertEqual(HistoryStore(fileURL: file, limit: 2).entries, store.entries)
    }

    @MainActor
    func testDeleteAndClearRemoveManagedImageFiles() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = HistoryStore(fileURL: folder.appendingPathComponent("history.json"))
        store.captureImage(try png())
        store.captureImage(try png(red: 0.2))
        let images = folder.appendingPathComponent("Images")
        let unrelated = images.appendingPathComponent("keep.txt")
        try Data("not managed".utf8).write(to: unrelated)
        store.remove(id: try XCTUnwrap(store.entries.first?.id))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: images.path).count, 2)
        store.clear()
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: images.path), ["keep.txt"])
    }

    @MainActor
    func testMissingAndTamperedImagesDoNotBreakTextHistoryOrReturnCorruptData() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("history.json")
        let store = HistoryStore(fileURL: file)
        store.capture("keep")
        store.captureImage(try png())
        let entry = try XCTUnwrap(store.entries.first)
        let attachment = try XCTUnwrap(entry.image)
        let asset = folder.appendingPathComponent("Images/\(attachment.fingerprint).png")
        var damaged = try Data(contentsOf: asset)
        damaged[damaged.count / 2] ^= 1
        try damaged.write(to: asset)
        XCTAssertNil(store.imageData(for: entry))
        try FileManager.default.removeItem(at: asset)
        let loaded = HistoryStore(fileURL: file)
        XCTAssertNil(loaded.storageIssue)
        XCTAssertEqual(loaded.entries.map(\.text), ["keep"])
    }

    @MainActor
    func testUnreadableIndexPreservesOriginalAndKeepsImagesInMemory() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("history.json")
        let original = Data("unreadable".utf8)
        try original.write(to: file)
        let store = HistoryStore(fileURL: file)
        let data = try png()
        store.captureImage(data)
        XCTAssertEqual(store.imageData(for: try XCTUnwrap(store.entries.first)), data)
        XCTAssertEqual(try Data(contentsOf: file), original)
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("Images").path))
        store.clear()
        XCTAssertNil(store.storageIssue)
    }

    @MainActor
    func testImageLimitsAndUntrustedMetadataAreRejected() throws {
        let store = HistoryStore()
        XCTAssertFalse(store.captureImage(Data("not an image".utf8)))
        XCTAssertFalse(store.captureImage(Data(repeating: 0, count: CapturePolicy.maximumImageBytes + 1)))
        XCTAssertFalse(CapturePolicy.acceptsImage(width: Int.max, height: Int.max, byteCount: 1))
        XCTAssertFalse(CapturePolicy.acceptsImage(width: 8_000, height: 8_000, byteCount: 1))
        XCTAssertFalse(CapturePolicy.acceptsImage(width: 0, height: 1, byteCount: 1))
        let json = "{\"fingerprint\":\"../../outside\",\"width\":8,\"height\":6,\"byteCount\":20}"
        XCTAssertFalse(try JSONDecoder().decode(ImageAttachment.self, from: Data(json.utf8)).hasValidMetadata)
        XCTAssertTrue(store.entries.isEmpty)
    }
}
