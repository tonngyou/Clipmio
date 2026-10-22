// Copyright (c) 2026 tonngyou. MIT License.
import Foundation

public struct ClipEntry: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let text: String
    public let image: ImageAttachment?
    public var copiedAt: Date
    public var sourceName: String?

    public init(id: UUID = UUID(), text: String, copiedAt: Date = .now,
                sourceName: String? = nil) {
        self.id = id
        self.text = text
        self.image = nil
        self.copiedAt = copiedAt
        self.sourceName = sourceName
    }

    public init(id: UUID = UUID(), image: ImageAttachment, copiedAt: Date = .now,
                sourceName: String? = nil) {
        self.id = id
        self.text = ""
        self.image = image
        self.copiedAt = copiedAt
        self.sourceName = sourceName
    }

    public var preview: String {
        text.split(whereSeparator: { $0.isNewline }).joined(separator: " ")
    }
}
