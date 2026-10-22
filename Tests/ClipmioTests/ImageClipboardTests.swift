import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest
import ClipmioCore
@testable import Clipmio

final class ImageClipboardTests: XCTestCase {
    @MainActor
    func testRapidImageTextChangesNeverFinishWithAStaleImage() async throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let store = HistoryStore()
        let monitor = ClipboardMonitor(history: store, pasteboard: pasteboard)
        let data = try fixture()
        var tasks: [Task<Void, Never>] = []
        for index in 0..<100 {
            pasteboard.clearContents()
            pasteboard.setData(data, forType: .png)
            if let task = monitor.poll() { tasks.append(task) }
            if index.isMultiple(of: 3) { await Task.yield() }
            pasteboard.clearContents()
            pasteboard.setString("newest-\(index)", forType: .string)
            monitor.poll()
        }
        for task in tasks { await task.value }
        XCTAssertEqual(store.entries.first?.text, "newest-99")
        XCTAssertNil(store.entries.first?.image)
        XCTAssertEqual(store.entries.count, 50)
        XCTAssertEqual(Set(store.entries.map(\.id)).count, store.entries.count)
        monitor.stop()
    }

    private func fixture(type: UTType = .png) throws -> Data {
        let context = try XCTUnwrap(CGContext(data: nil, width: 12, height: 8, bitsPerComponent: 8,
                                             bytesPerRow: 48, space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 0.5, green: 0.2, blue: 0.8, alpha: 0.5))
        context.fill(CGRect(x: 0, y: 0, width: 12, height: 8))
        let output = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(output, type.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try XCTUnwrap(context.makeImage()), nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return output as Data
    }

    @MainActor
    func testPNGBeatsAccompanyingURLAndCopiesAsAnImageWithoutRecapture() async throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let store = HistoryStore()
        let monitor = ClipboardMonitor(history: store, pasteboard: pasteboard)
        let data = try fixture()
        let item = NSPasteboardItem()
        item.setData(data, forType: .png)
        item.setString("https://example.com/image.png", forType: .string)
        item.setString("com.apple.Preview", forType: .init("org.nspasteboard.source"))
        pasteboard.clearContents()
        XCTAssertTrue(pasteboard.writeObjects([item]))
        await monitor.poll()?.value
        XCTAssertEqual(store.entries.count, 1)
        let entry = try XCTUnwrap(store.entries.first)
        XCTAssertNotNil(entry.image)
        XCTAssertEqual(entry.sourceBundleID, "com.apple.Preview")
        XCTAssertEqual(store.imageData(for: entry), data)
        XCTAssertTrue(monitor.copy(.image(data)))
        monitor.poll()
        XCTAssertEqual(store.entries, [entry])
        XCTAssertNil(pasteboard.string(forType: .string))
        XCTAssertEqual(pasteboard.data(forType: .png), data)
        XCTAssertNotNil(pasteboard.data(forType: .tiff))
        XCTAssertNotNil(pasteboard.readObjects(forClasses: [NSImage.self])?.first as? NSImage)
    }

    @MainActor
    func testTIFFConvertsToPNGWithDimensionsAndAlphaIntact() async throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let store = HistoryStore()
        let monitor = ClipboardMonitor(history: store, pasteboard: pasteboard)
        pasteboard.clearContents()
        let original = try fixture(type: .tiff)
        pasteboard.setData(original, forType: .tiff)
        await monitor.poll()?.value
        let entry = try XCTUnwrap(store.entries.first)
        XCTAssertEqual(entry.image?.width, 12)
        XCTAssertEqual(entry.image?.height, 8)
        let data = try XCTUnwrap(store.imageData(for: entry))
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        XCTAssertEqual(CGImageSourceGetType(source) as String?, UTType.png.identifier)
        let thumbnail = try XCTUnwrap(ClipboardImage.thumbnail(from: data))
        XCTAssertEqual(thumbnail.width, 12)
        XCTAssertEqual(thumbnail.height, 8)
        let context = try XCTUnwrap(CGContext(data: nil, width: 12, height: 8, bitsPerComponent: 8,
                                             bytesPerRow: 48, space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(thumbnail, in: CGRect(x: 0, y: 0, width: 12, height: 8))
        let pixel = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        XCTAssertEqual(Int(pixel[3]), 128, accuracy: 2)
        // Compare both through the same color space; Device RGB can differ from sRGB.
        let originalSource = try XCTUnwrap(CGImageSourceCreateWithData(original as CFData, nil))
        let originalBitmap = try XCTUnwrap(CGImageSourceCreateImageAtIndex(originalSource, 0, nil))
        let before = try XCTUnwrap(CGContext(data: nil, width: 12, height: 8, bitsPerComponent: 8,
                                            bytesPerRow: 48, space: CGColorSpaceCreateDeviceRGB(),
                                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        before.draw(originalBitmap, in: CGRect(x: 0, y: 0, width: 12, height: 8))
        let expected = try XCTUnwrap(before.data).assumingMemoryBound(to: UInt8.self)
        for channel in 0..<4 {
            XCTAssertEqual(Int(pixel[channel]), Int(expected[channel]), accuracy: 2)
        }
    }

    @MainActor
    func testConcealedImageAndPausedImageAreNotCaptured() async throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let store = HistoryStore()
        let monitor = ClipboardMonitor(history: store, pasteboard: pasteboard)
        let item = NSPasteboardItem()
        item.setData(try fixture(), forType: .png)
        item.setData(Data(), forType: .init("org.nspasteboard.ConcealedType"))
        pasteboard.clearContents()
        pasteboard.writeObjects([item])
        await monitor.poll()?.value
        XCTAssertTrue(store.entries.isEmpty)
        monitor.togglePause()
        pasteboard.clearContents()
        pasteboard.setData(try fixture(), forType: .png)
        await monitor.poll()?.value
        monitor.togglePause()
        await monitor.poll()?.value
        XCTAssertTrue(store.entries.isEmpty)
    }

    @MainActor
    func testChangedClipboardAndStoppedMonitorCancelPendingImageCapture() async throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let store = HistoryStore()
        let monitor = ClipboardMonitor(history: store, pasteboard: pasteboard)
        pasteboard.clearContents()
        pasteboard.setData(try fixture(), forType: .png)
        let old = monitor.poll()
        pasteboard.clearContents()
        pasteboard.setString("newer text", forType: .string)
        monitor.poll()
        await old?.value
        XCTAssertEqual(store.entries.map(\.text), ["newer text"])
        pasteboard.clearContents()
        pasteboard.setData(try fixture(), forType: .png)
        let pending = monitor.poll()
        monitor.stop()
        await pending?.value
        XCTAssertEqual(store.entries.map(\.text), ["newer text"])
    }

    @MainActor
    func testInvalidImageDoesNotDestroyClipboardAndCanFallBackToText() async throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let store = HistoryStore()
        let monitor = ClipboardMonitor(history: store, pasteboard: pasteboard)
        pasteboard.clearContents()
        pasteboard.setString("keep", forType: .string)
        XCTAssertFalse(monitor.copy(.image(Data("invalid".utf8))))
        XCTAssertEqual(pasteboard.string(forType: .string), "keep")
        pasteboard.setData(Data("invalid".utf8), forType: .png)
        await monitor.poll()?.value
        XCTAssertEqual(store.entries.map(\.text), ["keep"])
    }
    @MainActor
    func testSingleCopiedImageFileIsCapturedAndIndependentOfOriginalFile() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("sample.jpg")
        try fixture(type: .jpeg).write(to: file)
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let store = HistoryStore()
        let monitor = ClipboardMonitor(history: store, pasteboard: pasteboard)
        pasteboard.clearContents()
        pasteboard.setString(file.absoluteString, forType: .fileURL)
        await monitor.poll()?.value
        let entry = try XCTUnwrap(store.entries.first)
        XCTAssertEqual(entry.image?.width, 12)
        XCTAssertEqual(entry.image?.height, 8)
        try FileManager.default.removeItem(at: file)
        let saved = try XCTUnwrap(store.imageData(for: entry))
        XCTAssertNotNil(ImageAttachment(pngData: saved))
        XCTAssertTrue(monitor.copy(.image(saved)))
    }

    @MainActor
    func testRemoteFileURLAndNonImageFileAreNotReadAsImages() async throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let store = HistoryStore()
        let monitor = ClipboardMonitor(history: store, pasteboard: pasteboard)
        pasteboard.clearContents()
        pasteboard.setString("file://remote.invalid/shared/image.png", forType: .fileURL)
        await monitor.poll()?.value
        XCTAssertTrue(store.entries.isEmpty)
        pasteboard.clearContents()
        pasteboard.setString("file:///nonexistent/private-document.txt", forType: .fileURL)
        await monitor.poll()?.value
        XCTAssertTrue(store.entries.isEmpty)
    }

    func testJPEGClipboardPixelsNormalizeToPNG() throws {
        let jpeg = try fixture(type: .jpeg)
        let data = try XCTUnwrap(ClipboardImage.png(from: jpeg))
        let image = try XCTUnwrap(ImageAttachment(pngData: data))
        XCTAssertEqual(image.width, 12)
        XCTAssertEqual(image.height, 8)
        XCTAssertNotEqual(data, jpeg)
    }

    func testPreviewDecodeUsesRequestedResolutionWithAHardLimit() throws {
        let data = try fixture()
        let small = try XCTUnwrap(ClipboardImage.thumbnail(from: data, maximumPixelSize: 4))
        XCTAssertLessThanOrEqual(max(small.width, small.height), 4)
        let preview = try XCTUnwrap(ClipboardImage.thumbnail(from: data, maximumPixelSize: 4096))
        XCTAssertEqual(preview.width, 12)
        XCTAssertEqual(preview.height, 8)
    }

}
