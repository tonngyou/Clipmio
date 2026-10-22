// Copyright (c) 2026 tonngyou. MIT License.
import AppKit
import SwiftUI
#if SWIFT_PACKAGE
import ClipmioCore
#endif

struct ImageThumbnailView: View {
    let entry: ClipEntry
    let history: HistoryStore
    var compact = false
    @State private var thumbnail: NSImage?

    var body: some View {
        Group {
            if let thumbnail {
                Image(nsImage: thumbnail).resizable().scaledToFit().padding(compact ? 2 : 5)
            } else {
                Image(systemName: "photo").foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: compact ? 36 : 100)
        .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityHidden(true)
        .task(id: entry.image?.fingerprint) {
            guard let image = entry.image else { return }
            let key = image.fingerprint as NSString
            if let cached = ThumbnailCache.images.object(forKey: key) {
                thumbnail = cached
                return
            }
            guard let data = history.imageData(for: entry) else { return }
            let bitmap = await Task.detached(priority: .utility) { ClipboardImage.thumbnail(from: data) }.value
            guard !Task.isCancelled, let bitmap else { return }
            let result = NSImage(cgImage: bitmap, size: NSSize(width: bitmap.width, height: bitmap.height))
            ThumbnailCache.images.setObject(result, forKey: key, cost: bitmap.bytesPerRow * bitmap.height)
            thumbnail = result
        }
    }
}

@MainActor
private enum ThumbnailCache {
    static let images: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.totalCostLimit = 16 * 1024 * 1024
        return cache
    }()
}
