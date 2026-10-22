// Copyright (c) 2026 tonngyou. MIT License.
import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Local to this view's window; never intercepts another app or requests input monitoring.
@MainActor
final class LocalKeyMonitor {
    private var token: Any?

    func start(in view: NSView, handle: @escaping (NSEvent) -> Bool) {
        stop()
        token = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak view] event in
            guard let window = view?.window, event.window === window else { return event }
            return handle(event) ? nil : event
        }
    }

    func stop() {
        if let token { NSEvent.removeMonitor(token) }
        token = nil
    }
}

struct PreviewKeyboardActions {
    let close: () -> Void
    let paste: () -> Void

    @MainActor
    func handle(keyCode: UInt16, modifiers: NSEvent.ModifierFlags, isRepeat: Bool,
                composing: Bool) -> Bool {
        guard !composing, modifiers.intersection([.command, .control, .option, .shift]).isEmpty else { return false }
        switch Int(keyCode) {
        case kVK_Space, kVK_Escape:
            if !isRepeat { close() }
        case kVK_Return, kVK_ANSI_KeypadEnter:
            if !isRepeat { paste() }
        default:
            return false
        }
        return true
    }
}

struct PreviewKeyboardControl: NSViewRepresentable {
    let actions: PreviewKeyboardActions

    func makeCoordinator() -> Coordinator { Coordinator(actions: actions) }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.monitor.start(in: view) { [weak coordinator = context.coordinator, weak view] event in
            let composing = (view?.window?.firstResponder as? NSTextView)?.hasMarkedText() ?? false
            return coordinator?.actions.handle(keyCode: event.keyCode, modifiers: event.modifierFlags,
                                               isRepeat: event.isARepeat, composing: composing) ?? false
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) { context.coordinator.actions = actions }

    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) { coordinator.monitor.stop() }

    @MainActor
    final class Coordinator {
        let monitor = LocalKeyMonitor()
        var actions: PreviewKeyboardActions
        init(actions: PreviewKeyboardActions) { self.actions = actions }
    }
}
