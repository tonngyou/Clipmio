// Copyright (c) 2026 tonngyou. MIT License.
import AppKit
import Carbon
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
    private let hotKey = GlobalHotKey(shortcut: AppSettings.shared.shortcut)
    private var isDemo = false
    private var loginItem: LoginItemManager!
    private var restarting = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        let openHistoryAtLaunch = LaunchPresentation.shouldOpenHistory(
            event: NSAppleEventManager.shared().currentAppleEvent,
            arguments: ProcessInfo.processInfo.arguments)
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
            button.toolTip = "Clipmio · 贴觅"
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item
        popover.behavior = .transient
        popover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        popover.contentSize = ClipmioTheme.panelSize
        hotKey.onTrigger = { [weak self] in self?.togglePopover() }
        hotKey.start()
        if openHistoryAtLaunch {
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(500))
                // A Dock reopen may already have shown it during startup.
                self?.showHistory()
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

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        let history = NSMenuItem(title: L10n.text("Show History"), action: #selector(showHistory), keyEquivalent: "")
        history.target = self
        menu.addItem(history)
        let restart = NSMenuItem(title: L10n.text("Restart Clipmio"), action: #selector(restartApp), keyEquivalent: "")
        restart.target = self
        menu.addItem(restart)
        // Regular applications receive the system's standard Quit command below.
        return menu
    }

    @objc private func showHistory() {
        if popover.isShown {
            popover.contentViewController?.view.window?.makeKey()
            NSApp.activate()
        } else {
            togglePopover()
        }
    }

    @objc private func statusItemClicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showStatusMenu()
        } else {
            togglePopover()
        }
    }

    private func showStatusMenu() {
        guard let button = statusItem?.button else { return }
        pasteService.cancel()
        popover.performClose(nil)
        let menu = NSMenu()
        func add(_ title: String, action: Selector, key: String = "") {
            let item = NSMenuItem(title: L10n.text(title), action: action, keyEquivalent: key)
            item.target = self
            menu.addItem(item)
        }
        add("Show History", action: #selector(togglePopover))
        add(monitor.isPaused ? "Resume Monitoring" : "Pause Monitoring", action: #selector(toggleMonitoring))
        menu.addItem(.separator())
        add("Restart Clipmio", action: #selector(restartApp))
        add("Quit Clipmio", action: #selector(quitApp), key: "q")
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY), in: button)
    }

    @objc private func toggleMonitoring() { monitor.togglePause() }
    @objc private func quitApp() { NSApp.terminate(nil) }

    @objc private func restartApp() {
        guard !restarting else { return }
        restarting = true
        pasteService.cancel()
        popover.performClose(nil)
        hotKey.stop()
        monitor.stop()
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.activates = false
        configuration.arguments = ProcessInfo.processInfo.arguments.filter { ["--demo", "--dark"].contains($0) }
        configuration.arguments.append("--background")
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { [weak self] app, error in
            Task { @MainActor in
                guard let self else { return }
                if app != nil && error == nil {
                    NSApp.terminate(nil)
                } else {
                    self.restarting = false
                    if !self.isDemo { self.monitor.start() }
                    self.hotKey.start()
                    let alert = NSAlert()
                    alert.messageText = L10n.text("Restart failed")
                    alert.informativeText = L10n.text("Restart failed explanation")
                    alert.addButton(withTitle: L10n.text("OK"))
                    NSApp.activate()
                    alert.runModal()
                }
            }
        }
    }

    @objc private func togglePopover() {
        guard !restarting else { return }
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
                          onRestart: { [weak self] in self?.restartApp() },
                          onPreviewChange: { [weak self] visible in
                              self?.resizeHistoryPanel(preview: visible)
                          })
        )
        presentPopover()
    }

    private func resizeHistoryPanel(preview: Bool) {
        // Resize once, without a second AppKit snapshot animation over SwiftUI content.
        popover.animates = false
        popover.contentSize = preview ? ClipmioTheme.previewPanelSize : ClipmioTheme.panelSize
        popover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private func presentPopover() {
        guard !popover.isShown, let button = statusItem?.button else { return }
        popover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        popover.appearance = NSApp.effectiveAppearance
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        NSApp.activate()
    }

    private func copy(_ entry: ClipEntry) {
        guard !isDemo else { return }
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
        guard !isDemo else { return }
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
            history.capture(sample.0, sourceName: sample.1, sourceBundleID: ["Notes": "com.apple.Notes", "Terminal": "com.apple.Terminal", "Safari": "com.apple.Safari", "Preview": "com.apple.Preview"][sample.1],
                            at: Date.now.addingTimeInterval(Double(index - samples.count) * 180))
        }
        if ProcessInfo.processInfo.arguments.contains("--stress") {
            for index in 0..<50 {
                history.capture("\(index) · " + String(repeating: "Long clipboard text · 長文字佈局測試 👨‍👩‍👧‍👦\n", count: 200),
                                sourceName: "Clipmio Demo")
            }
        }
    }
}

@MainActor
enum LaunchPresentation {
    static func shouldOpenHistory(event: NSAppleEventDescriptor?, arguments: [String]) -> Bool {
        if arguments.contains("--background") { return false }
        if event?.eventID == AEEventID(kAEOpenApplication),
           let reason = event?.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue,
           reason == OSType(keyAELaunchedAsLogInItem) || reason == OSType(keyAELaunchedAsServiceItem) {
            return false
        }
        return true
    }
}
