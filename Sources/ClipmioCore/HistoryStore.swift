// Copyright (c) 2026 tonngyou. MIT License.
import Foundation
import Observation

@Observable @MainActor
public final class HistoryStore {
    public enum StorageIssue: Equatable {
        case unreadableHistory
        case failedToSave
    }

    public private(set) var entries: [ClipEntry] = []
    public private(set) var storageIssue: StorageIssue?
    public let limit: Int
    @ObservationIgnored private let fileURL: URL?
    @ObservationIgnored private var savingBlocked = false
    @ObservationIgnored private var imageCache: [String: Data] = [:]

    public init(fileURL: URL? = nil, limit: Int = 50) {
        self.fileURL = fileURL
        self.limit = max(1, limit)
        load()
    }

    public func capture(_ text: String, sourceName: String? = nil, at date: Date = .now) {
        guard CapturePolicy.accepts(text: text) else { return }
        let existing = entries.first { $0.image == nil && $0.text == text }
        entries.removeAll { $0.image == nil && $0.text == text }
        entries.insert(ClipEntry(id: existing?.id ?? UUID(), text: text,
                                 copiedAt: date, sourceName: sourceName), at: 0)
        entries = Array(entries.prefix(limit))
        save()
    }

    @discardableResult
    public func captureImage(_ pngData: Data, sourceName: String? = nil, at date: Date = .now) -> Bool {
        guard let image = ImageAttachment(pngData: pngData) else { return false }
        let existing = entries.first { $0.image?.fingerprint == image.fingerprint }
        entries.removeAll { $0.image?.fingerprint == image.fingerprint }
        imageCache[image.fingerprint] = pngData
        entries.insert(ClipEntry(id: existing?.id ?? UUID(), image: image,
                                 copiedAt: date, sourceName: sourceName), at: 0)
        entries = Array(entries.prefix(limit))
        save()
        return true
    }

    public func imageData(for entry: ClipEntry) -> Data? {
        guard let image = entry.image, image.hasValidMetadata else { return nil }
        if let data = imageCache[image.fingerprint] { return data }
        guard let url = imageURL(image), imageFileExists(image),
              let data = try? Data(contentsOf: url), ImageAttachment(pngData: data) == image else { return nil }
        return data
    }

    public func matching(_ query: String) -> [ClipEntry] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return entries }
        return entries.filter {
            $0.text.localizedStandardContains(query)
                || ($0.sourceName?.localizedStandardContains(query) ?? false)
                || ($0.image != nil && "Image 图片 圖片".localizedStandardContains(query))
        }
    }

    public func remove(id: UUID) {
        entries.removeAll { $0.id == id }
        save()
    }

    /// Explicitly clearing history also resets an unreadable history file.
    public func clear() {
        entries.removeAll()
        savingBlocked = false
        save()
    }

    private func load() {
        guard let fileURL, FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            // JSON escaping can expand a text byte to six bytes (e.g. control characters).
            guard ((attributes[.size] as? NSNumber)?.intValue ?? 0) <= 96 * 1024 * 1024 else {
                throw CocoaError(.fileReadTooLarge)
            }
            let decoded = try JSONDecoder().decode([ClipEntry].self, from: Data(contentsOf: fileURL))
            var seenText = Set<String>()
            var seenImages = Set<String>()
            var seenIDs = Set<UUID>()
            entries = Array(decoded.filter {
                let valid: Bool
                if let image = $0.image {
                    valid = image.hasValidMetadata && imageFileExists(image)
                        && seenImages.insert(image.fingerprint).inserted
                } else {
                    valid = CapturePolicy.accepts(text: $0.text) && seenText.insert($0.text).inserted
                }
                return valid && seenIDs.insert($0.id).inserted
            }.prefix(limit))
        } catch {
            // Keep the original file intact instead of overwriting unreadable data.
            savingBlocked = true
            storageIssue = .unreadableHistory
        }
    }

    private func save() {
        let fingerprints = Set(entries.compactMap { $0.image?.fingerprint })
        imageCache = imageCache.filter { fingerprints.contains($0.key) }
        guard let fileURL, !savingBlocked else { return }
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
            try FileManager.default.setAttributes([.posixPermissions: 0o700],
                                                  ofItemAtPath: directory.path)
            if !imageCache.isEmpty {
                let images = directory.appendingPathComponent("Images", isDirectory: true)
                try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true,
                                                        attributes: [.posixPermissions: 0o700])
                try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: images.path)
                for (fingerprint, data) in imageCache {
                    let url = images.appendingPathComponent(fingerprint).appendingPathExtension("png")
                    try data.write(to: url, options: .atomic)
                    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
                }
            }
            let data = try JSONEncoder().encode(entries)
            try data.write(to: fileURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600],
                                                  ofItemAtPath: fileURL.path)
            imageCache.removeAll()
            // Remove managed attachments only after the new index is safely committed.
            removeUnusedImages(keeping: fingerprints)
            storageIssue = nil
        } catch {
            storageIssue = .failedToSave
        }
    }

    private func imageURL(_ image: ImageAttachment) -> URL? {
        guard image.hasValidMetadata else { return nil }
        return fileURL?.deletingLastPathComponent().appendingPathComponent("Images", isDirectory: true)
            .appendingPathComponent(image.fingerprint).appendingPathExtension("png")
    }

    private func imageFileExists(_ image: ImageAttachment) -> Bool {
        guard let url = imageURL(image),
              let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else { return false }
        return (attributes[.size] as? NSNumber)?.intValue == image.byteCount
    }

    private func removeUnusedImages(keeping fingerprints: Set<String>) {
        guard let directory = fileURL?.deletingLastPathComponent().appendingPathComponent("Images"),
              let files = try? FileManager.default.contentsOfDirectory(at: directory,
                                                                      includingPropertiesForKeys: nil) else { return }
        for file in files where file.pathExtension == "png" {
            let name = file.deletingPathExtension().lastPathComponent
            guard name.utf8.count == 64, name.utf8.allSatisfy({
                (48...57).contains($0) || (97...102).contains($0)
            }), !fingerprints.contains(name) else { continue }
            try? FileManager.default.removeItem(at: file)
        }
    }
}
