// Copyright (c) 2026 tonngyou. MIT License.
import Foundation
import CryptoKit
import ImageIO
import UniformTypeIdentifiers

/// Only metadata goes in history.json. The lossless PNG lives in Images/<fingerprint>.png.
public struct ImageAttachment: Codable, Equatable, Sendable {
    public let fingerprint: String
    public let width: Int
    public let height: Int
    public let byteCount: Int

    public init?(pngData: Data) {
        guard pngData.count <= CapturePolicy.maximumImageBytes,
              let source = CGImageSourceCreateWithData(pngData as CFData, nil),
              CGImageSourceGetType(source) as String? == UTType.png.identifier,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              CapturePolicy.acceptsImage(width: width, height: height, byteCount: pngData.count) else { return nil }
        self.width = width
        self.height = height
        self.byteCount = pngData.count
        self.fingerprint = SHA256.hash(data: pngData).map { String(format: "%02x", $0) }.joined()
    }

    public var hasValidMetadata: Bool {
        fingerprint.utf8.count == 64 && fingerprint.utf8.allSatisfy {
            (48...57).contains($0) || (97...102).contains($0)
        } && CapturePolicy.acceptsImage(width: width, height: height, byteCount: byteCount)
    }
}
