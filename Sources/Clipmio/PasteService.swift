// Copyright (c) 2026 tonngyou. MIT License.
import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Observation

enum PasteResult: Equatable {
    case pasted, cancelled, clipboardWriteFailed, accessibilityRequired
    case noTarget, focusTimeout, clipboardChanged, inputNotReleased, injectionFailed
}

/// Injectable system boundaries keep tests from typing into real applications.
@MainActor
struct PasteEnvironment {
    var copy: (ClipboardContent) -> Int?
    var clipboardChangeCount: () -> Int
    var isTrusted: () -> Bool
    var targetExists: (pid_t) -> Bool
    var inputIsReleased: () -> Bool
    var activate: (pid_t) -> Bool
    var frontmostPID: () -> pid_t?
    var sendPaste: (pid_t) -> Bool
    var wait: () async throws -> Void
}

@MainActor
struct PasteCoordinator {
    let environment: PasteEnvironment
    var attempts = 40

    func perform(content: ClipboardContent, target: pid_t?, dismiss: () -> Void) async -> PasteResult {
        guard !Task.isCancelled else { return .cancelled }
        guard let changeCount = environment.copy(content) else { return .clipboardWriteFailed }
        let closesAfterCopy: Bool
        if case .image = content { closesAfterCopy = true } else { closesAfterCopy = false }
        if !closesAfterCopy {
            guard let target, environment.targetExists(target) else { return .noTarget }
            guard environment.isTrusted() else { return .accessibilityRequired }
        }

        // Keep the popover open until Return and shortcut modifiers are released.
        // Otherwise a held Return can repeat into the destination application.
        do {
            var released = false
            for _ in 0..<max(1, attempts) {
                guard !Task.isCancelled else { return .cancelled }
                guard environment.clipboardChangeCount() == changeCount else { return .clipboardChanged }
                if !closesAfterCopy, let target, !environment.targetExists(target) { return .noTarget }
                if environment.inputIsReleased() { released = true; break }
                try await environment.wait()
            }
            guard released else { return .inputNotReleased }
            guard !Task.isCancelled else { return .cancelled }
            if !closesAfterCopy && !environment.isTrusted() { return .accessibilityRequired }
            dismiss()
            guard let target, environment.targetExists(target) else { return .noTarget }
            guard environment.activate(target) else { return .focusTimeout }
            guard environment.isTrusted() else { return .accessibilityRequired }

            var stableFocus = 0
            for _ in 0..<max(1, attempts) {
                guard !Task.isCancelled else { return .cancelled }
                guard environment.clipboardChangeCount() == changeCount else { return .clipboardChanged }
                guard environment.targetExists(target) else { return .noTarget }
                if environment.frontmostPID() == target {
                    stableFocus += 1
                } else {
                    // Do not take focus back if the user switches away mid-paste.
                    if stableFocus > 0 { return .focusTimeout }
                }
                if stableFocus >= 2 && environment.inputIsReleased() {
                    guard environment.isTrusted() else { return .accessibilityRequired }
                    return environment.sendPaste(target) ? .pasted : .injectionFailed
                }
                try await environment.wait()
            }
            return .focusTimeout
        } catch {
            return .cancelled
        }
    }
}

@Observable @MainActor
final class PasteService {
    private(set) var lastFailure: PasteResult?
    @ObservationIgnored private let coordinator: PasteCoordinator
    @ObservationIgnored private var pending: Task<Void, Never>?
    @ObservationIgnored private var requestID = UUID()

    init(monitor: ClipboardMonitor, pasteboard: NSPasteboard = .general) {
        coordinator = PasteCoordinator(environment: PasteEnvironment(
            copy: { monitor.copy($0) ? pasteboard.changeCount : nil },
            clipboardChangeCount: { pasteboard.changeCount },
            isTrusted: { AXIsProcessTrusted() },
            targetExists: { pid in
                pid != ProcessInfo.processInfo.processIdentifier
                    && NSRunningApplication(processIdentifier: pid).map { !$0.isTerminated } == true
            },
            inputIsReleased: {
                let flags = CGEventSource.flagsState(.combinedSessionState)
                return flags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl]).isEmpty
                    && !CGEventSource.keyState(.combinedSessionState, key: CGKeyCode(kVK_Return))
                    && !CGEventSource.keyState(.combinedSessionState, key: CGKeyCode(kVK_ANSI_KeypadEnter))
            },
            activate: { NSRunningApplication(processIdentifier: $0)?.activate() ?? false },
            frontmostPID: { NSWorkspace.shared.frontmostApplication?.processIdentifier },
            sendPaste: { pid in
                guard let events = Self.makePasteEvents() else { return false }
                // Address the original process, never whichever app happens to be active later.
                events.0.postToPid(pid)
                events.1.postToPid(pid)
                return true
            },
            wait: { try await Task.sleep(for: .milliseconds(20)) }
        ))
    }

    init(coordinator: PasteCoordinator) {
        self.coordinator = coordinator
    }

    @discardableResult
    func paste(_ content: ClipboardContent, into target: NSRunningApplication?,
               dismiss: @escaping () -> Void, showFailure: @escaping () -> Void) -> Task<Void, Never> {
        cancel()
        lastFailure = nil
        let id = requestID
        let targetPID = target?.processIdentifier
        let task = Task { [weak self] in
            guard let self else { return }
            var dismissed = false
            let result = await coordinator.perform(content: content, target: targetPID) {
                dismissed = true
                dismiss()
            }
            guard requestID == id else { return }
            pending = nil
            guard result != .pasted && result != .cancelled else { return }
            lastFailure = result
            // Image selection closes the panel even when automatic paste is unavailable.
            // Keep the failure for the next manual opening instead of reopening over the target.
            if case .image = content { return }
            if dismissed { showFailure() }
        }
        pending = task
        return task
    }

    func cancel() {
        requestID = UUID()
        pending?.cancel()
        pending = nil
    }

    func clearFailure() { lastFailure = nil }

    func prepareForPresentation() {
        cancel()
        if lastFailure == .accessibilityRequired && coordinator.environment.isTrusted() {
            lastFailure = nil
        }
    }

    func reportUnavailableContent() {
        cancel()
        lastFailure = .clipboardWriteFailed
    }

    func openAccessibilitySettings() {
        // Opening the settings pane never grants access; the user controls the switch.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    static func makePasteEvents() -> (CGEvent, CGEvent)? {
        guard let source = CGEventSource(stateID: .privateState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false) else { return nil }
        down.flags = .maskCommand
        up.flags = .maskCommand
        return (down, up)
    }
}
