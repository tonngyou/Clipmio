// Copyright (c) 2026 tonngyou. MIT License.
import AppKit
import SwiftUI

enum HistoryTab: Int, CaseIterable {
    case all, favorites

    func neighbor(by offset: Int) -> HistoryTab? {
        HistoryTab(rawValue: rawValue + offset)
    }

    static func dragOffset(x: CGFloat, y: CGFloat) -> Int? {
        guard abs(x) >= 48, abs(x) > abs(y) * 1.6 else { return nil }
        return x < 0 ? 1 : -1
    }
}

/// One horizontal gesture advances at most one tab. Vertical scrolling is never consumed.
struct TabScrollTracker {
    struct Result: Equatable {
        var consumed = false
        var offset: Int? = nil
    }
    private enum Axis: Equatable { case horizontal, vertical }
    private var axis: Axis?
    private var totalX = 0.0
    private var totalY = 0.0
    private var advanced = false
    private var lastTimestamp: TimeInterval?
    private var lastAdvance: TimeInterval?

    mutating func reset() {
        axis = nil
        totalX = 0
        totalY = 0
        advanced = false
        lastTimestamp = nil
    }

    mutating func scroll(x: Double, y: Double, precise: Bool, phase: NSEvent.Phase = [],
                         momentum: NSEvent.Phase = [], timestamp: TimeInterval) -> Result {
        // Momentum must never start or repeat a navigation.
        if !momentum.isEmpty { return Result(consumed: axis == .horizontal) }
        if phase.contains(.began) || phase.contains(.mayBegin)
            || (phase.isEmpty && lastTimestamp.map { timestamp - $0 > 0.28 || timestamp < $0 } == true) {
            reset()
        }
        lastTimestamp = timestamp
        if phase.contains(.cancelled) {
            let consumed = axis == .horizontal
            reset()
            return Result(consumed: consumed)
        }
        totalX += x
        totalY += y
        if axis == nil, max(abs(totalX), abs(totalY)) >= 4 {
            if abs(totalX) > abs(totalY) * 1.6 { axis = .horizontal }
            else if abs(totalY) >= abs(totalX) { axis = .vertical }
        }
        guard axis == .horizontal else { return Result() }
        // End events only finish the current gesture; they cannot select another tab.
        guard !phase.contains(.ended), !advanced, abs(totalX) >= (precise ? 40 : 8) else {
            return Result(consumed: true)
        }
        advanced = true
        lastAdvance = timestamp
        return Result(consumed: true, offset: totalX < 0 ? 1 : -1)
    }

    mutating func swipe(x: Double, y: Double, timestamp: TimeInterval) -> Int? {
        guard abs(x) > abs(y), x != 0,
              lastAdvance.map({ timestamp - $0 > 0.3 }) ?? true else { return nil }
        lastAdvance = timestamp
        return x < 0 ? 1 : -1
    }
}

/// Local to the list/heading under the pointer; no global event tap or extra permission.
struct HistoryTabGesture: NSViewRepresentable {
    let isActive: () -> Bool
    let onNavigate: (Int) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.start(in: view)
        return view
    }

    func updateNSView(_ view: NSView, context: Context) { context.coordinator.parent = self }
    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) { coordinator.stop() }

    @MainActor
    final class Coordinator {
        var parent: HistoryTabGesture
        private var tracker = TabScrollTracker()
        private var token: Any?

        init(parent: HistoryTabGesture) { self.parent = parent }

        func start(in view: NSView) {
            stop()
            token = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .swipe, .otherMouseDown]) {
                [weak self, weak view] event in
                guard let self, let view, let window = view.window, event.window === window,
                      self.parent.isActive(),
                      view.bounds.contains(view.convert(event.locationInWindow, from: nil)),
                      event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { return event }
                switch event.type {
                case .scrollWheel:
                    let shifted = event.modifierFlags.contains(.shift) && event.scrollingDeltaX == 0
                    let result = self.tracker.scroll(
                        x: Double(shifted ? event.scrollingDeltaY : event.scrollingDeltaX),
                        y: Double(shifted ? 0 : event.scrollingDeltaY),
                        precise: event.hasPreciseScrollingDeltas, phase: event.phase,
                        momentum: event.momentumPhase, timestamp: event.timestamp)
                    if let offset = result.offset { self.parent.onNavigate(offset) }
                    return result.consumed ? nil : event
                case .swipe:
                    if let offset = self.tracker.swipe(x: Double(event.deltaX), y: Double(event.deltaY), timestamp: event.timestamp) {
                        self.parent.onNavigate(offset)
                        return nil
                    }
                case .otherMouseDown:
                    if event.buttonNumber == 3 || event.buttonNumber == 4 {
                        self.parent.onNavigate(event.buttonNumber == 3 ? -1 : 1)
                        return nil
                    }
                default: break
                }
                return event
            }
        }

        func stop() {
            if let token { NSEvent.removeMonitor(token) }
            token = nil
            tracker = TabScrollTracker()
        }
    }
}
