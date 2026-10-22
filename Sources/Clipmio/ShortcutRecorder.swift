// Copyright (c) 2026 tonngyou. MIT License.
import AppKit
import SwiftUI

/// Captures only while this button is the first responder; no global event tap.
struct ShortcutRecorder: NSViewRepresentable {
    let label: String
    let onRecordingChange: (Bool) -> Void
    let onCapture: (KeyboardShortcut) -> Void
    let onInvalid: () -> Void

    func makeNSView(context: Context) -> RecordingButton {
        let button = RecordingButton()
        button.bezelStyle = .rounded
        button.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        button.target = button
        button.action = #selector(RecordingButton.beginRecording)
        NotificationCenter.default.addObserver(button, selector: #selector(RecordingButton.windowResignedKey(_:)),
                                               name: NSWindow.didResignKeyNotification, object: nil)
        return button
    }

    func updateNSView(_ button: RecordingButton, context: Context) {
        button.parent = self
        button.title = button.isRecording ? L10n.text("Press shortcut…") : label
        button.setAccessibilityLabel(L10n.text("Record shortcut"))
    }

    static func dismantleNSView(_ button: RecordingButton, coordinator: ()) {
        button.finishRecording()
        NotificationCenter.default.removeObserver(button)
    }

    final class RecordingButton: NSButton {
        var parent: ShortcutRecorder?
        private(set) var isRecording = false
        override var acceptsFirstResponder: Bool { true }

        @objc func beginRecording() {
            guard !isRecording else { finishRecording(); return }
            isRecording = true
            parent?.onRecordingChange(true)
            title = L10n.text("Press shortcut…")
            window?.makeFirstResponder(self)
        }

        func finishRecording() {
            guard isRecording else { return }
            isRecording = false
            title = parent?.label ?? ""
            parent?.onRecordingChange(false)
        }

        @objc func windowResignedKey(_ notification: Notification) {
            if (notification.object as? NSWindow) === window { finishRecording() }
        }

        override func resignFirstResponder() -> Bool {
            finishRecording()
            return super.resignFirstResponder()
        }

        override func viewWillMove(toWindow newWindow: NSWindow?) {
            if newWindow == nil { finishRecording() }
            super.viewWillMove(toWindow: newWindow)
        }

        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            guard isRecording, window?.firstResponder === self else {
                return super.performKeyEquivalent(with: event)
            }
            handle(event)
            return true
        }

        override func keyDown(with event: NSEvent) {
            if isRecording { handle(event) } else { super.keyDown(with: event) }
        }

        private func handle(_ event: NSEvent) {
            guard !event.isARepeat else { return }
            if event.keyCode == 53 { finishRecording(); return }
            let shortcut = KeyboardShortcut(event: event)
            guard shortcut.isValid else { parent?.onInvalid(); return }
            parent?.onCapture(shortcut)
            finishRecording()
        }
    }
}
