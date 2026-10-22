// Copyright (c) 2026 tonngyou. MIT License.
import AppKit
import SwiftUI
#if SWIFT_PACKAGE
import ClipmioCore
#endif

struct EntryPreviewView: View {
    let entry: ClipEntry
    let history: HistoryStore
    let onClose: () -> Void
    let onCopy: () -> Void
    let onPaste: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: onClose) {
                    Label(L10n.text("Back to history"), systemImage: "chevron.left")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                Divider().frame(height: 22)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.text(entry.image == nil ? "Text preview" : "Image preview"))
                        .font(.system(size: 15, weight: .semibold))
                    HStack(spacing: 6) {
                        Text(entry.sourceName ?? L10n.text(entry.image == nil ? "Text" : "Image"))
                        Text("·")
                        Text(entry.copiedAt, format: .dateTime.year().month().day().hour().minute())
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: entry.image == nil ? "doc.text" : "photo")
                    .font(.system(size: 19, weight: .light))
                    .foregroundStyle(ClipmioTheme.accent(for: colorScheme))
                    .accessibilityHidden(true)
            }
            .padding(20)
            Divider()

            if let image = entry.image {
                LargeImagePreview(entry: entry, history: history, attachment: image)
            } else {
                HStack {
                    Text(L10n.text("Characters") + " · \(entry.text.count)")
                    Spacer()
                    Text(L10n.text("Select text to copy"))
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 22)
                .padding(.top, 15)
                ScrollView {
                    Text(verbatim: entry.text)
                        .font(.system(size: 14, design: .monospaced))
                        .lineSpacing(5)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(22)
                }
            }

            Divider()
            HStack(spacing: 10) {
                Text(L10n.text("Preview keyboard hint"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(L10n.text("Copy"), action: onCopy)
                    .buttonStyle(.bordered)
                Button(action: onPaste) {
                    Label(L10n.text("Paste"), systemImage: "return")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .background(PreviewKeyboardControl(actions: PreviewKeyboardActions(close: onClose, paste: onPaste)))
    }
}

private struct LargeImagePreview: View {
    let entry: ClipEntry
    let history: HistoryStore
    let attachment: ImageAttachment
    @State private var image: NSImage?
    @State private var failed = false
    @State private var zoom: CGFloat = 1

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Text("\(attachment.width) × \(attachment.height)")
                Text("·")
                Text(ByteCountFormatter.string(fromByteCount: Int64(attachment.byteCount), countStyle: .file))
                Spacer()
                Button { zoom = max(1, zoom - 0.5) } label: {
                    Image(systemName: "minus.magnifyingglass")
                }
                .disabled(zoom <= 1 || image == nil)
                .accessibilityLabel(L10n.text("Zoom out"))
                Button(L10n.text("Fit image")) { zoom = 1 }
                    .disabled(zoom == 1)
                Button { zoom = min(4, zoom + 0.5) } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
                .disabled(zoom >= 4 || image == nil)
                .accessibilityLabel(L10n.text("Zoom in"))
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .buttonStyle(.borderless)

            GeometryReader { geometry in
                if let image {
                    let size = image.size
                    let fit = min(geometry.size.width / max(1, size.width),
                                  geometry.size.height / max(1, size.height))
                    ScrollView([.horizontal, .vertical]) {
                        Image(nsImage: image)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: size.width * fit * zoom, height: size.height * fit * zoom)
                            .frame(minWidth: geometry.size.width, minHeight: geometry.size.height)
                    }
                } else if failed {
                    ContentUnavailableView(L10n.text("Image unavailable"), systemImage: "photo.badge.exclamationmark")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(20)
        .task(id: attachment.fingerprint) {
            image = nil
            failed = false
            zoom = 1
            guard let data = history.imageData(for: entry) else { failed = true; return }
            let bitmap = await Task.detached(priority: .userInitiated) {
                ClipboardImage.thumbnail(from: data, maximumPixelSize: 4096)
            }.value
            guard !Task.isCancelled else { return }
            guard let bitmap else { failed = true; return }
            image = NSImage(cgImage: bitmap, size: NSSize(width: bitmap.width, height: bitmap.height))
        }
    }
}
