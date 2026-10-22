// Copyright (c) 2026 tonngyou. MIT License.
import Foundation

public struct HistorySelection: Sendable {
    public private(set) var selectedID: UUID?

    public init() {}

    public mutating func select(_ id: UUID, in ids: [UUID]) {
        selectedID = ids.contains(id) ? id : ids.first
    }

    public mutating func reconcile(with ids: [UUID], reset: Bool = false) {
        if reset || selectedID == nil || !ids.contains(where: { $0 == selectedID }) {
            selectedID = ids.first
        }
    }

    public mutating func move(by offset: Int, in ids: [UUID]) {
        guard !ids.isEmpty else { selectedID = nil; return }
        guard let selectedID, let index = ids.firstIndex(of: selectedID) else {
            self.selectedID = ids.first
            return
        }
        let destination = min(ids.count - 1, max(0, index + offset))
        self.selectedID = ids[destination]
    }
}
