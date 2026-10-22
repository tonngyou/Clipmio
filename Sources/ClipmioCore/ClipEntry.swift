// Copyright (c) 2026 tonngyou. MIT License.
import Foundation

public struct ClipEntry: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let text: String
    public let image: ImageAttachment?
    public var copiedAt: Date
    public var sourceName: String?
    public var sourceBundleID: String?
    public var isFavorite: Bool

    public init(id: UUID = UUID(), text: String, copiedAt: Date = .now,
                sourceName: String? = nil, sourceBundleID: String? = nil, isFavorite: Bool = false) {
        self.id = id
        self.text = text
        self.image = nil
        self.copiedAt = copiedAt
        self.sourceName = sourceName
        self.sourceBundleID = sourceBundleID
        self.isFavorite = isFavorite
    }

    public init(id: UUID = UUID(), image: ImageAttachment, copiedAt: Date = .now,
                sourceName: String? = nil, sourceBundleID: String? = nil, isFavorite: Bool = false) {
        self.id = id
        self.text = ""
        self.image = image
        self.copiedAt = copiedAt
        self.sourceName = sourceName
        self.sourceBundleID = sourceBundleID
        self.isFavorite = isFavorite
    }

    private enum CodingKeys: String, CodingKey {
        case id, text, image, copiedAt, sourceName, sourceBundleID, isFavorite
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        text = try values.decode(String.self, forKey: .text)
        image = try values.decodeIfPresent(ImageAttachment.self, forKey: .image)
        copiedAt = try values.decode(Date.self, forKey: .copiedAt)
        sourceName = try values.decodeIfPresent(String.self, forKey: .sourceName)
        sourceBundleID = try values.decodeIfPresent(String.self, forKey: .sourceBundleID)
        isFavorite = try values.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
    }

    public var preview: String {
        // A two-line card must not lay out a whole large clipboard payload.
        // The full text remains available for search, preview, and copy-back.
        String(text.prefix(400)).split(whereSeparator: { $0.isNewline }).joined(separator: " ")
    }
}
