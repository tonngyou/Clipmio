// Copyright (c) 2026 tonngyou. MIT License.
import AppKit
import ImageIO
import UniformTypeIdentifiers
#if SWIFT_PACKAGE
import ClipmioCore
#endif

enum ClipboardContent: Equatable, Sendable {
    case text(String)
    case image(Data)
}

enum ClipboardImage {
    static let maximumInputBytes = 64 * 1024 * 1024
    static let readableTypes: [UTType] = [.png, .tiff, .jpeg, .heic, .heif]

    /// PNG is kept losslessly; other supported formats become a lossless PNG of their pixels.
    static func png(from data: Data) -> Data? {
        guard !data.isEmpty, data.count <= maximumInputBytes,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source) as String?,
              readableTypes.map(\.identifier).contains(type),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              CapturePolicy.acceptsImage(width: width, height: height, byteCount: 1),
              let bitmap = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCache: false] as CFDictionary)
        else { return nil }
        if type == UTType.png.identifier {
            return ImageAttachment(pngData: data) == nil ? nil : data
        }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil)
        else { return nil }
        var metadata: [CFString: Any] = [:]
        if let orientation = properties[kCGImagePropertyOrientation] {
            metadata[kCGImagePropertyOrientation] = orientation
        }
        CGImageDestinationAddImage(destination, bitmap, metadata as CFDictionary)
        guard CGImageDestinationFinalize(destination), ImageAttachment(pngData: output as Data) != nil else { return nil }
        return output as Data
    }

    static func thumbnail(from data: Data, maximumPixelSize: Int = 320) -> CGImage? {
        guard ImageAttachment(pngData: data) != nil,
              let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, min(4096, maximumPixelSize)),
            kCGImageSourceShouldCacheImmediately: true
        ] as CFDictionary)
    }
}
