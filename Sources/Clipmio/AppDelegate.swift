// Copyright (c) 2026 tonngyou. MIT License.
import AppKit
import SwiftUI
#if SWIFT_PACKAGE
import ClipmioCore
#endif

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var history: HistoryStore!
    private var monitor: ClipboardMonitor!
    private var pasteService: PasteService!
    private var previousApplication: NSRunningApplication?
    private var lastExternalApplication: NSRunningApplication?
    private let hotKey = GlobalHotKey()
    private var isDemo = false
    private var loginItem: LoginItemManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let front = NSWorkspace.shared.frontmostApplication
        if front?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            lastExternalApplication = front
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(applicationActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification, object: nil)
        let demo = ProcessInfo.processInfo.arguments.contains("--demo")
        isDemo = demo
        loginItem = LoginItemManager(canManage: !demo && Bundle.main.bundleURL.pathExtension == "app")
        if demo && ProcessInfo.processInfo.arguments.contains("--dark") {
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
        history = HistoryStore(fileURL: demo ? nil : AppPaths.historyFile)
        monitor = ClipboardMonitor(history: history)
        pasteService = PasteService(monitor: monitor)
        if demo {
            seedDemo()
        } else {
            monitor.start()
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = ClipmioArtwork.menuBarImage()
                ?? NSImage(systemSymbolName: "clipboard", accessibilityDescription: "Clipmio")
            button.toolTip = "Clipmio · 贴觅 — \(GlobalHotKey.shortcutLabel)"
            button.target = self
            button.action = #selector(togglePopover)
        }
        statusItem = item
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = ClipmioTheme.panelSize
        hotKey.onTrigger = { [weak self] in self?.togglePopover() }
        hotKey.start()
        if demo {
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(500))
                self?.togglePopover()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        pasteService?.cancel()
        hotKey.stop()
        monitor?.stop()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !popover.isShown { togglePopover() }
        return false
    }

    @objc private func togglePopover() {
        if popover.isShown {
            dismissPopover()
            return
        }
        pasteService.prepareForPresentation()
        let front = NSWorkspace.shared.frontmostApplication
        if let front, front.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApplication = front
        } else {
            previousApplication = lastExternalApplication
        }
        // A fresh view clears an old query and focuses search on every invocation.
        popover.contentSize = ClipmioTheme.panelSize
        popover.contentViewController = NSHostingController(rootView:
            ClipboardView(history: history, monitor: monitor, hotKey: hotKey,
                          pasteService: pasteService, isDemo: isDemo,
                          settings: AppSettings.shared, loginItem: loginItem,
                          onPaste: { [weak self] entry in self?.paste(entry) },
                          onCopy: { [weak self] entry in self?.copy(entry) },
                          onDismiss: { [weak self] in self?.dismissPopover() },
                          onPreviewChange: { [weak self] visible in
                              self?.popover.contentSize = visible ? ClipmioTheme.previewPanelSize : ClipmioTheme.panelSize
                          })
        )
        presentPopover()
    }

    private func presentPopover() {
        guard !popover.isShown, let button = statusItem?.button else { return }
        popover.appearance = NSApp.effectiveAppearance
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        NSApp.activate()
    }

    private func copy(_ entry: ClipEntry) {
        pasteService.cancel()
        pasteService.clearFailure()
        guard let content = content(for: entry), monitor.copy(content) else {
            pasteService.reportUnavailableContent()
            return
        }
        popover.performClose(nil)
        previousApplication?.activate()
    }

    private func paste(_ entry: ClipEntry) {
        guard let content = content(for: entry) else {
            pasteService.reportUnavailableContent()
            return
        }
        pasteService.paste(content, into: previousApplication,
                           dismiss: { [weak self] in self?.popover.performClose(nil) },
                           showFailure: { [weak self] in self?.presentPopover() })
    }

    private func content(for entry: ClipEntry) -> ClipboardContent? {
        if entry.image != nil {
            return history.imageData(for: entry).map(ClipboardContent.image)
        }
        return .text(entry.text)
    }

    private func dismissPopover() {
        pasteService.cancel()
        popover.performClose(nil)
        previousApplication?.activate()
    }

    @objc private func applicationActivated(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        lastExternalApplication = app
    }

    private func seedDemo() {
        if let url = ClipmioTheme.resourceBundle.url(forResource: "ClipmioLogo", withExtension: "png"),
           let data = try? Data(contentsOf: url) {
            history.captureImage(data, sourceName: "Preview", at: .now.addingTimeInterval(-30 * 60))
        }
        let samples = [
            ("Keep the small things within reach.", "Notes"),
            ("https://github.com/tonngyou", "Safari"),
            ("swift test\nxcodebuild -project Clipmio.xcodeproj -scheme Clipmio build", "Terminal"),
            ("设计不必复杂，顺手就好。", "Notes"),
            ("Clipmio · 贴觅\n复制过的，随时找回。", "Clipmio")
        ]
        for (index, sample) in samples.enumerated() {
            history.capture(sample.0, sourceName: sample.1,
                            at: Date.now.addingTimeInterval(Double(index - samples.count) * 180))
        }
    }
}
