// Copyright (c) 2026 tonngyou. MIT License.
import AppKit
import SwiftUI
#if SWIFT_PACKAGE
import ClipmioCore
#endif

struct ClipboardView: View {
    let history: HistoryStore
    let monitor: ClipboardMonitor
    let hotKey: GlobalHotKey
    let pasteService: PasteService
    let isDemo: Bool
    let settings: AppSettings
    let loginItem: LoginItemManager
    let onPaste: (ClipEntry) -> Void
    let onCopy: (ClipEntry) -> Void
    let onDismiss: () -> Void
    let onPreviewChange: (Bool) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var query = ""
    @State private var hoveredID: UUID?
    @State private var confirmClear = false
    @State private var selection = HistorySelection()
    @State private var previewEntry: ClipEntry?
    @State private var isNavigatingHistory = false
    @State private var showingSettings = false

    private var accent: Color { ClipmioTheme.accent(for: colorScheme) }
    private var surface: Color {
        colorScheme == .dark ? Color(white: 0.145) : .white
    }
    private var canvas: Color {
        colorScheme == .dark ? Color(red: 0.105, green: 0.102, blue: 0.13)
                            : Color(red: 0.972, green: 0.969, blue: 0.986)
    }
    private var results: [ClipEntry] { history.matching(query) }
    private var resultIDs: [UUID] { results.map(\.id) }
    private var selectedEntry: ClipEntry? {
        results.first { $0.id == selection.selectedID } ?? results.first
    }

    var body: some View {
        Group {
            if showingSettings {
                SettingsView(settings: settings, loginItem: loginItem,
                             onClose: { showingSettings = false })
            } else if let entry = previewEntry {
                EntryPreviewView(entry: entry, history: history,
                                 onClose: { previewEntry = nil },
                                 onCopy: { onCopy(entry) }, onPaste: { onPaste(entry) })
            } else {
                historyContent
            }
        }
        .frame(width: previewEntry == nil ? ClipmioTheme.panelSize.width : ClipmioTheme.previewPanelSize.width,
               height: previewEntry == nil ? ClipmioTheme.panelSize.height : ClipmioTheme.previewPanelSize.height)
        .background {
            LinearGradient(colors: [surface, canvas], startPoint: .top, endPoint: .bottom)
        }
        .tint(accent)
        .environment(\.locale, settings.language.locale)
        .onChange(of: previewEntry != nil) { _, visible in onPreviewChange(visible) }
        .alert(L10n.text("Clear all history?"), isPresented: $confirmClear) {
            Button(L10n.text("Cancel"), role: .cancel) {}
            Button(L10n.text("Clear History"), role: .destructive) { history.clear() }
        } message: {
            Text(L10n.text("Clear history explanation"))
        }
        .onAppear { selection.reconcile(with: resultIDs) }
        .onChange(of: query) { _, _ in
            pasteService.cancel()
            isNavigatingHistory = false
            selection.reconcile(with: resultIDs, reset: true)
        }
        .onChange(of: resultIDs) { _, ids in
            selection.reconcile(with: ids)
            if let entry = previewEntry, !ids.contains(entry.id) { previewEntry = nil }
        }
    }

    private var historyContent: some View {
        VStack(spacing: 0) {
            header
            search
                .padding(.horizontal, 20)
            notices
            collectionHeading
            if results.isEmpty {
                emptyState
            } else {
                ScrollViewReader { reader in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(results) { entry in row(entry).id(entry.id) }
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 2)
                        .padding(.bottom, 14)
                    }
                    .onChange(of: selection.selectedID) { _, id in
                        if let id { reader.scrollTo(id, anchor: .center) }
                    }
                }
            }
            footer
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ClipmioMark()
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text("Clipmio")
                    .font(.system(size: 23, weight: .semibold, design: .rounded))
                    .tracking(-0.7)
                Text(L10n.text("Your copies, within reach."))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Menu {
                if !hotKey.isRegistered {
                    Button(L10n.text("Retry Shortcut")) { hotKey.start() }
                    Divider()
                }
                Button {
                    monitor.togglePause()
                } label: {
                    Label(L10n.text(monitor.isPaused ? "Resume Monitoring" : "Pause Monitoring"),
                          systemImage: monitor.isPaused ? "play" : "pause")
                }
                Button(role: .destructive) { confirmClear = true } label: {
                    Label(L10n.text("Clear History"), systemImage: "trash")
                }
                .disabled(history.entries.isEmpty && history.storageIssue == nil)
                Divider()
                Button {
                    pasteService.cancel()
                    showingSettings = true
                } label: {
                    Label(L10n.text("Settings…"), systemImage: "gearshape")
                }
                Button(L10n.text("About Clipmio")) { showAbout() }
                Link("GitHub · tonngyou", destination: URL(string: "https://github.com/tonngyou")!)
                Divider()
                Button(L10n.text("Quit Clipmio")) { NSApp.terminate(nil) }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 9))
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel(L10n.text("More options"))
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 21)
    }

    private var search: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(accent.opacity(0.8))
            HistorySearchField(text: $query,
                               onMove: {
                                   pasteService.cancel()
                                   isNavigatingHistory = true
                                   selection.move(by: $0, in: resultIDs)
                               },
                               onSubmit: { if let entry = selectedEntry { onPaste(entry) } },
                               onEscape: {
                                   pasteService.cancel()
                                   if query.isEmpty { onDismiss() } else { query = "" }
                               },
                               onPreview: selectedEntry == nil ? nil : {
                                   if let entry = selectedEntry { showPreview(entry) }
                               },
                               isNavigatingHistory: isNavigatingHistory)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.text("Clear search"))
            }
        }
        .padding(.horizontal, 13)
        .frame(height: 42)
        .background(accent.opacity(colorScheme == .dark ? 0.08 : 0.045),
                    in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(accent.opacity(0.13)))
    }

    @ViewBuilder private var notices: some View {
        if let failure = pasteService.lastFailure {
            pasteFailureNotice(failure)
        }
        if hotKey.registrationError != nil {
            notice(L10n.text("Shortcut unavailable notice"), symbol: "keyboard.badge.ellipsis")
        }
        if let issue = history.storageIssue {
            notice(L10n.text(issue == .unreadableHistory ? "Unreadable history notice" : "Save failed notice"),
                   symbol: "exclamationmark.triangle")
        }
    }

    private func notice(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.caption)
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 12)
    }

    private var collectionHeading: some View {
        HStack(spacing: 7) {
            Text(L10n.text(query.isEmpty ? "Recent copies" : "Search results"))
                .font(.system(size: 11, weight: .medium))
            Text("\(results.count)")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .monospacedDigit()
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.primary.opacity(0.045), in: Capsule())
            Spacer()
            Button {
                if let entry = selectedEntry { showPreview(entry) }
            } label: {
                Image(systemName: "eye").font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .disabled(selectedEntry == nil)
            .help(L10n.text("Preview selected item"))
            .accessibilityLabel(L10n.text("Preview selected item"))
            if hotKey.isRegistered {
                keyCap(GlobalHotKey.shortcutLabel)
                    .help(L10n.text("Show or hide history"))
            }
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 22)
        .padding(.top, 19)
        .padding(.bottom, 11)
    }

    private func row(_ entry: ClipEntry) -> some View {
        let selected = selection.selectedID == entry.id
        let hovered = hoveredID == entry.id
        return Button { onPaste(entry) } label: {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: entry.image != nil ? "photo" : isLink(entry.text) ? "link" : "text.alignleft")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(selected ? accent : .secondary)
                    .frame(width: 30, height: 32)
                    .background(accent.opacity(selected ? 0.09 : 0.045),
                                in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 9) {
                    if entry.image != nil {
                        ImageThumbnailView(entry: entry, history: history)
                    }
                    Text(entryDescription(entry))
                        .font(.system(size: 13))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 5) {
                        Text(entry.sourceName ?? L10n.text(entry.image == nil ? "Text" : "Image"))
                            .lineLimit(1)
                        Text("·")
                        Text(entry.copiedAt, format: .dateTime.hour().minute())
                            .lineLimit(1)
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                }
                Image(systemName: "return")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(accent)
                    .frame(width: 22, height: 20)
                    .background(accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 5))
                    .opacity(hovered || selected ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 13).fill(surface)
                RoundedRectangle(cornerRadius: 13)
                    .fill(accent.opacity(selected ? 0.09 : hovered ? 0.035 : 0))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 13)
                    .strokeBorder(selected ? accent.opacity(0.33) : .primary.opacity(0.045))
            }
            .contentShape(RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(.plain)
        .onHover { hoveredID = $0 ? entry.id : nil }
        .help(L10n.text("Paste this item"))
        .accessibilityLabel(L10n.text("Paste") + ": " + entryDescription(entry))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .contextMenu {
            Button(L10n.text("Preview")) { showPreview(entry) }
            Button(L10n.text("Paste")) { onPaste(entry) }
            Button(L10n.text("Copy")) { onCopy(entry) }
            Button(L10n.text("Delete"), role: .destructive) { history.remove(id: entry.id) }
        }
    }

    private func showPreview(_ entry: ClipEntry) {
        pasteService.cancel()
        selection.select(entry.id, in: resultIDs)
        previewEntry = entry
    }

    private func entryDescription(_ entry: ClipEntry) -> String {
        if let image = entry.image {
            return L10n.text("Image") + " · \(image.width) × \(image.height)"
        }
        return entry.preview
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            if query.isEmpty {
                ClipmioMark().frame(width: 76, height: 76).padding(.bottom, 6)
            } else {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(accent.opacity(0.6))
                    .padding(.bottom, 12)
            }
            Text(L10n.text(query.isEmpty ? "A fresh clipboard." : "No matches yet."))
                .font(.system(size: 14, weight: .medium))
            Text(L10n.text(query.isEmpty ? "Copy some text to get started." : "Try a different word or app name."))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func keyCap(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .padding(.horizontal, 5)
            .frame(height: 19)
            .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.primary.opacity(0.06)))
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Rectangle().fill(.primary.opacity(0.06)).frame(height: 1)
            HStack(spacing: 6) {
                Circle()
                    .fill(monitor.isPaused || isDemo ? Color.orange : accent)
                    .frame(width: 5, height: 5)
                Text(L10n.text(isDemo ? "Demo" : monitor.isPaused ? "Paused" : "Local only"))
                Spacer(minLength: 8)
                Text(L10n.text("Navigate and paste"))
            }
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 22)
            .frame(height: 40)
        }
        .background(surface.opacity(0.65))
    }

    private func pasteFailureNotice(_ failure: PasteResult) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(L10n.text(pasteFailureKey(failure)), systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
            if failure == .accessibilityRequired {
                Button(L10n.text("Enable Automatic Paste")) { pasteService.openAccessibilitySettings() }
                    .font(.caption)
                    .buttonStyle(.link)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private func pasteFailureKey(_ failure: PasteResult) -> String {
        switch failure {
        case .accessibilityRequired: "Paste accessibility notice"
        case .noTarget: "Paste target notice"
        case .clipboardChanged: "Paste clipboard changed notice"
        case .clipboardWriteFailed: "Paste copy failed notice"
        case .inputNotReleased: "Paste release keys notice"
        default: "Paste focus failed notice"
        }
    }

    private func isLink(_ text: String) -> Bool {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.contains(where: { $0.isWhitespace }), let url = URL(string: text) else { return false }
        return ["http", "https"].contains(url.scheme?.lowercased() ?? "") && url.host != nil
    }

    private func showAbout() {
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Clipmio · 贴觅",
            .applicationVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0",
            .version: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1",
            .credits: NSAttributedString(string: L10n.text("About description") + "\n\n"
                                        + "tonngyou\nhttps://github.com/tonngyou\n\nMIT License"),
            .init(rawValue: "Copyright"): "Copyright © 2026 tonngyou"
        ])
    }
}

#Preview("Light") {
    ClipboardPreview.make()
}

#Preview("Dark") {
    ClipboardPreview.make().preferredColorScheme(.dark)
}

@MainActor
private enum ClipboardPreview {
    static func make() -> some View {
        let history = HistoryStore(fileURL: nil)
        history.capture("Clipmio · 贴觅\n复制过的，随时找回。", sourceName: "Clipmio")
        history.capture("设计不必复杂，顺手就好。", sourceName: "Notes")
        history.capture("https://github.com/tonngyou", sourceName: "Safari")
        let monitor = ClipboardMonitor(history: history)
        return ClipboardView(history: history, monitor: monitor, hotKey: GlobalHotKey(),
                             pasteService: PasteService(monitor: monitor), isDemo: true,
                             settings: .shared, loginItem: LoginItemManager(canManage: false),
                             onPaste: { _ in }, onCopy: { _ in }, onDismiss: {}, onPreviewChange: { _ in })
    }
}
