// Copyright (c) 2026 tonngyou. MIT License.
import AppKit
import SwiftUI
#if SWIFT_PACKAGE
import ClipmioCore
#endif

struct SourceAppIcon: View {
    let entry: ClipEntry
    @State private var icon: NSImage?

    var body: some View {
        Group {
            if let icon {
                Image(nsImage: icon).resizable().interpolation(.high).scaledToFit()
            } else {
                Image(systemName: entry.image == nil ? "doc.text" : "photo")
                    .font(.system(size: 17)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 7))
            }
        }
        .frame(width: 30, height: 30)
        .accessibilityHidden(true)
        .task(id: (entry.sourceBundleID ?? "") + ":" + (entry.sourceName ?? "")) {
            icon = SourceIconCache.image(bundleID: entry.sourceBundleID, name: entry.sourceName)
        }
    }
}

@MainActor
enum SourceIconCache {
    private static let images = NSCache<NSString, NSImage>()
    private static var misses = Set<String>()

    static func image(bundleID: String?, name: String?) -> NSImage? {
        let key = (bundleID ?? "") + ":" + (name ?? "")
        if let image = images.object(forKey: key as NSString) { return image }
        guard !misses.contains(key) else { return nil }
        var url = bundleID.flatMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
        if url == nil, let name, !name.isEmpty {
            url = NSWorkspace.shared.runningApplications.first {
                $0.localizedName?.localizedCaseInsensitiveCompare(name) == .orderedSame
            }?.bundleURL
            // Legacy history has only a name. Search local application folders once per source.
            if url == nil, !name.contains("/"), name != ".", name != ".." {
                for folder in ["/Applications", "/System/Applications", "/System/Applications/Utilities",
                               FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path] {
                    let candidate = URL(fileURLWithPath: folder).appendingPathComponent(name + ".app")
                    if FileManager.default.fileExists(atPath: candidate.path) { url = candidate; break }
                }
            }
        }
        guard let url else {
            if misses.count >= 200 { misses.removeAll() }
            misses.insert(key)
            return nil
        }
        let image = NSWorkspace.shared.icon(forFile: url.path)
        image.size = NSSize(width: 32, height: 32)
        images.countLimit = 100
        images.setObject(image, forKey: key as NSString)
        return image
    }
}
