// Copyright (c) 2026 tonngyou. MIT License.
import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Keep text editing in the search field while routing navigation to the history.
struct HistorySearchField: NSViewRepresentable {
    @Binding var text: String
    let onMove: (Int) -> Void
    let onSubmit: () -> Void
    let onEscape: () -> Void
    var onPreview: (() -> Void)? = nil
    var onSwitchTab: ((Int) -> Void)? = nil
    var isNavigatingHistory = false
    var isActive: () -> Bool = { true }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> NSTextField {
        let field = SearchTextField()
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 13)
        field.placeholderString = L10n.text("Search your copies…")
        field.usesSingleLineMode = true
        field.cell?.isScrollable = true
        field.delegate = context.coordinator
        field.setAccessibilityLabel(L10n.text("Search history"))
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        context.coordinator.monitor.start(in: field) { [weak coordinator = context.coordinator, weak field] event in
            guard event.keyCode == UInt16(kVK_Space), let field,
                  let editor = field.currentEditor() as? NSTextView,
                  field.window?.firstResponder === editor else { return false }
            return coordinator?.handleSpace(searchText: editor.string, composing: editor.hasMarkedText(),
                                             modifiers: event.modifierFlags, isRepeat: event.isARepeat) ?? false
        }
        return field
    }

    static func dismantleNSView(_ field: NSTextField, coordinator: Coordinator) { coordinator.monitor.stop() }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        let placeholder = L10n.text("Search your copies…")
        if field.placeholderString != placeholder { field.placeholderString = placeholder }
        let label = L10n.text("Search history")
        if field.accessibilityLabel() != label { field.setAccessibilityLabel(label) }
        // Replacing an active marked string would break Chinese/Japanese composition.
        let composing = (field.currentEditor() as? NSTextView)?.hasMarkedText() ?? false
        if !composing && field.stringValue != text { field.stringValue = text }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: HistorySearchField
        let monitor = LocalKeyMonitor()

        init(parent: HistorySearchField) { self.parent = parent }

        @discardableResult
        func handleSpace(searchText: String, composing: Bool, modifiers: NSEvent.ModifierFlags,
                         isRepeat: Bool) -> Bool {
            guard parent.isActive(), !composing, let preview = parent.onPreview,
                  modifiers.intersection([.command, .control, .option, .shift]).isEmpty,
                  searchText.isEmpty || parent.isNavigatingHistory else { return false }
            if !isRepeat { preview() }
            return true
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            handle(command: commandSelector, composing: textView.hasMarkedText(),
                   modifiers: NSApp.currentEvent?.modifierFlags ?? [], searchText: textView.string)
        }

        @discardableResult
        func handle(command: Selector, composing: Bool, modifiers: NSEvent.ModifierFlags,
                    searchText: String? = nil) -> Bool {
            guard parent.isActive(), !composing,
                  modifiers.intersection([.command, .control, .option, .shift]).isEmpty else { return false }
            switch command {
            case #selector(NSResponder.moveLeft(_:)), #selector(NSResponder.moveBackward(_:)):
                guard let switchTab = parent.onSwitchTab,
                      (searchText ?? parent.text).isEmpty || parent.isNavigatingHistory else { return false }
                switchTab(-1)
            case #selector(NSResponder.moveRight(_:)), #selector(NSResponder.moveForward(_:)):
                guard let switchTab = parent.onSwitchTab,
                      (searchText ?? parent.text).isEmpty || parent.isNavigatingHistory else { return false }
                switchTab(1)
            case #selector(NSResponder.moveUp(_:)):
                parent.onMove(-1)
            case #selector(NSResponder.moveDown(_:)):
                parent.onMove(1)
            case #selector(NSResponder.insertNewline(_:)):
                parent.onSubmit()
            case #selector(NSResponder.cancelOperation(_:)):
                parent.onEscape()
            default:
                return false
            }
            return true
        }
    }
}

private final class SearchTextField: NSTextField {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            window.makeFirstResponder(self)
        }
    }
}
