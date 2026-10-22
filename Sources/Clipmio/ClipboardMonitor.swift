// Copyright (c) 2026 tonngyou. MIT License.
import AppKit
import Observation
import UniformTypeIdentifiers
#if SWIFT_PACKAGE
import ClipmioCore
#endif

@Observable @MainActor
final class ClipboardMonitor {
    private(set) var isPaused = false
    @ObservationIgnored private let history: HistoryStore
    @ObservationIgnored private let pasteboard: NSPasteboard
    @ObservationIgnored private var lastChange: Int
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var imageTask: Task<Void, Never>?

    init(history: HistoryStore, pasteboard: NSPasteboard = .general) {
        self.history = history
        self.pasteboard = pasteboard
        lastChange = pasteboard.changeCount
    }

    func start() {
        stop()
        lastChange = pasteboard.changeCount
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.poll() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        imageTask?.cancel()
        imageTask = nil
        timer?.invalidate()
        timer = nil
    }

    func togglePause() {
        imageTask?.cancel()
        // Changes copied while paused must not be picked up on resume.
        lastChange = pasteboard.changeCount
        isPaused.toggle()
    }

    @discardableResult
    func copy(_ text: String) -> Bool {
        copy(.text(text))
    }

    @discardableResult
    func copy(_ content: ClipboardContent) -> Bool {
        let item = NSPasteboardItem()
        switch content {
        case .text(let text):
            guard item.setString(text, forType: .string) else { return false }
        case .image(let data):
            guard ImageAttachment(pngData: data) != nil,
                  NSImage(data: data) != nil,
                  item.setData(data, forType: .png) else { return false }
            // Native image consumers commonly request TIFF. PNG remains the lossless source.
            if let tiff = NSImage(data: data)?.tiffRepresentation {
                item.setData(tiff, forType: .tiff)
            }
        }
        imageTask?.cancel()
        pasteboard.clearContents()
        let success = pasteboard.writeObjects([item])
        lastChange = pasteboard.changeCount
        return success
    }

    @discardableResult
    func poll() -> Task<Void, Never>? {
        let current = pasteboard.changeCount
        guard current != lastChange else { return nil }
        imageTask?.cancel()
        lastChange = current
        guard !isPaused else { return nil }

        let types = Set((pasteboard.types ?? []).map(\.rawValue))
        let declaredSource = pasteboard.string(forType: .init("org.nspasteboard.source"))
        let frontmost = NSWorkspace.shared.frontmostApplication
        let sources = [declaredSource, frontmost?.bundleIdentifier].compactMap { $0 }
        guard CapturePolicy.allows(types: types, sourceBundleIDs: sources) else { return nil }

        let sourceName: String?
        if let declaredSource, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: declaredSource) {
            sourceName = FileManager.default.displayName(atPath: url.path)
                .replacingOccurrences(of: ".app", with: "")
        } else {
            sourceName = frontmost?.localizedName
        }
        let sourceBundleID = declaredSource ?? frontmost?.bundleIdentifier
        // A copied picture can also advertise a URL/string. Prefer the actual pixels.
        let imageTypes = ClipboardImage.readableTypes.map { NSPasteboard.PasteboardType($0.identifier) }
        let copiedFile = singleImageFileURL()
        if !types.isDisjoint(with: Set(imageTypes.map(\.rawValue))) || copiedFile != nil {
            let task = Task { @MainActor [weak self] in
                guard let self else { return }
                for type in imageTypes {
                    guard !Task.isCancelled, pasteboard.changeCount == current, !isPaused else { return }
                    guard let data = pasteboard.data(forType: type), data.count <= ClipboardImage.maximumInputBytes
                    else { continue }
                    let worker = Task.detached(priority: .utility) { ClipboardImage.png(from: data) }
                    let png = await withTaskCancellationHandler(operation: { await worker.value },
                                                               onCancel: { worker.cancel() })
                    guard !Task.isCancelled, pasteboard.changeCount == current, !isPaused else { return }
                    if let png {
                        history.captureImage(png, sourceName: sourceName, sourceBundleID: sourceBundleID)
                        return
                    }
                }
                if let copiedFile {
                    let worker = Task.detached(priority: .utility) {
                        guard let values = try? copiedFile.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                              values.isRegularFile == true, let size = values.fileSize,
                              size > 0, size <= ClipboardImage.maximumInputBytes,
                              let data = try? Data(contentsOf: copiedFile) else { return nil as Data? }
                        return ClipboardImage.png(from: data)
                    }
                    let png = await withTaskCancellationHandler(operation: { await worker.value },
                                                               onCancel: { worker.cancel() })
                    guard !Task.isCancelled, pasteboard.changeCount == current, !isPaused else { return }
                    if let png {
                        history.captureImage(png, sourceName: sourceName, sourceBundleID: sourceBundleID)
                        return
                    }
                }
                if let text = pasteboard.string(forType: .string), pasteboard.changeCount == current {
                    history.capture(text, sourceName: sourceName, sourceBundleID: sourceBundleID)
                }
            }
            imageTask = task
            return task
        }
        guard let text = pasteboard.string(forType: .string), pasteboard.changeCount == current else { return nil }
        history.capture(text, sourceName: sourceName, sourceBundleID: sourceBundleID)
        return nil
    }

    private func singleImageFileURL() -> URL? {
        guard pasteboard.pasteboardItems?.count == 1,
              let value = pasteboard.string(forType: .fileURL), let url = URL(string: value),
              url.isFileURL, url.host == nil || url.host == "" || url.host == "localhost",
              let type = UTType(filenameExtension: url.pathExtension.lowercased()),
              ClipboardImage.readableTypes.contains(where: { type.conforms(to: $0) }) else { return nil }
        return url
    }
}
