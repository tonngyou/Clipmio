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
    let onRestart: () -> Void
    let onPreviewChange: (Bool) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var filterHighlight
    @State private var query = ""
    @State private var hoveredID: UUID?
    @State private var confirmClear = false
    @State private var selection = HistorySelection()
    @State private var previewEntry: ClipEntry?
    @State private var isNavigatingHistory = false
    @State private var showingSettings = false
    @State private var selectedTab: HistoryTab = .all
    private var favoritesOnly: Bool { selectedTab == .favorites }

    private var accent: Color { ClipmioTheme.accent(for: colorScheme) }
    private var surface: Color {
        colorScheme == .dark ? Color(white: 0.145) : .white
    }
    private var canvas: Color {
        colorScheme == .dark ? Color(red: 0.105, green: 0.102, blue: 0.13)
                            : Color(red: 0.972, green: 0.969, blue: 0.986)
    }
    private var results: [ClipEntry] { history.matching(query, favoritesOnly: favoritesOnly) }
    private var resultIDs: [UUID] { results.map(\.id) }
    private var selectedEntry: ClipEntry? {
        results.first { $0.id == selection.selectedID } ?? results.first
    }

    private var navigationAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.1) : .smooth(duration: 0.24)
    }
    var body: some View {
        Group {
            if showingSettings {
                SettingsView(settings: settings, loginItem: loginItem, hotKey: hotKey,
                             onClose: { showingSettings = false })
                    .frame(width: ClipmioTheme.panelSize.width, height: ClipmioTheme.panelSize.height)
                    .modifier(ContentEntrance(reduceMotion: reduceMotion))
            } else if let entry = previewEntry {
                EntryPreviewView(entry: entry, history: history,
                                 onClose: closePreview,
                                 onCopy: { onCopy(entry) }, onPaste: { onPaste(entry) },
                                 isActive: { previewEntry?.id == entry.id && !showingSettings })
                    .frame(width: ClipmioTheme.previewPanelSize.width, height: ClipmioTheme.previewPanelSize.height)
                    .modifier(ContentEntrance(reduceMotion: reduceMotion))
            } else {
                historyContent
                    .frame(width: ClipmioTheme.panelSize.width, height: ClipmioTheme.panelSize.height)
            }
        }
        .frame(width: previewEntry == nil ? ClipmioTheme.panelSize.width : ClipmioTheme.previewPanelSize.width,
               height: previewEntry == nil ? ClipmioTheme.panelSize.height : ClipmioTheme.previewPanelSize.height,
               alignment: .topLeading)
        .clipped()
        .background {
            LinearGradient(colors: [surface, canvas], startPoint: .top, endPoint: .bottom)
        }
        .tint(accent)
        .environment(\.locale, settings.language.locale)
        .onChange(of: previewEntry != nil) { _, visible in onPreviewChange(visible) }
        .alert(L10n.text("Clear recent history?"), isPresented: $confirmClear) {
            Button(L10n.text("Cancel"), role: .cancel) {}
            Button(L10n.text("Clear Recent History"), role: .destructive) { history.clear(keepingFavorites: true) }
        } message: {
            Text(L10n.text("Clear recent explanation"))
        }
        .onAppear { selection.reconcile(with: resultIDs) }
        .onChange(of: query) { _, _ in
            pasteService.cancel()
            isNavigatingHistory = false
            selection.reconcile(with: resultIDs, reset: true)
        }
        .onChange(of: favoritesOnly) { _, _ in
            pasteService.cancel()
            selection.reconcile(with: resultIDs, reset: true)
        }
        .onChange(of: resultIDs) { _, ids in
            selection.reconcile(with: ids)
            if let entry = previewEntry, !ids.contains(entry.id) { closePreview() }
        }
    }

    private var historyContent: some View {
        VStack(spacing: 0) {
            header
            search
                .padding(.horizontal, 20)
            notices
            VStack(spacing: 0) {
                collectionHeading
                historyResults
                    .modifier(ContentEntrance(reduceMotion: reduceMotion, offset: favoritesOnly ? 6 : -6))
                    .id(selectedTab)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            }
            .contentShape(Rectangle())
            .highPriorityGesture(DragGesture(minimumDistance: 20).onEnded { value in
                if let offset = HistoryTab.dragOffset(x: value.translation.width, y: value.translation.height) {
                    navigateTabs(offset)
                }
            })
            .background(HistoryTabGesture(isActive: { previewEntry == nil && !showingSettings },
                                         onNavigate: navigateTabs).allowsHitTesting(false))
            footer
        }
    }

    @ViewBuilder private var historyResults: some View {
        if results.isEmpty {
            emptyState
        } else {
            ScrollViewReader { reader in
                ScrollView {
                    // Keep the bounded regular stack used by the stability fix.
                    VStack(spacing: settings.compactLayout ? 5 : 8) {
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
    }

    private var header: some View {
        HStack(spacing: 12) {
            ClipmioMark()
                .frame(width: settings.compactLayout ? 30 : 40, height: settings.compactLayout ? 30 : 40)
            VStack(alignment: .leading, spacing: 4) {
                Text("Clipmio")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .tracking(-0.7)
                if !settings.compactLayout {
                    Text(L10n.text("Your copies, within reach."))
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
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
                    Label(L10n.text("Clear Recent History"), systemImage: "trash")
                }
                .disabled(!history.entries.contains(where: { !$0.isFavorite }) && history.storageIssue == nil)
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
                Button(L10n.text("Restart Clipmio"), action: onRestart)
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
        .padding(.vertical, settings.compactLayout ? 12 : 16)
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
                               onSwitchTab: {
                                   navigateTabs($0)
                                   isNavigatingHistory = true
                               },
                               isNavigatingHistory: isNavigatingHistory,
                               isActive: { previewEntry == nil && !showingSettings })
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.text("Clear search"))
            }
        }
        .padding(.horizontal, 13)
        .frame(height: 36)
        .background(accent.opacity(colorScheme == .dark ? 0.08 : 0.045),
                    in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(accent.opacity(0.13)))
    }

    @ViewBuilder private var notices: some View {
        if let failure = pasteService.lastFailure {
            pasteFailureNotice(failure)
        }
        if hotKey.registrationError != nil {
            notice(hotKey.shortcutLabel + " · " + L10n.text("Custom shortcut unavailable notice"), symbol: "keyboard.badge.ellipsis")
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
            filterButton("All copies", favorites: false)
            filterButton("Favorites", favorites: true)
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
                keyCap(hotKey.shortcutLabel)
                    .help(L10n.text("Show or hide history"))
            }
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, 9)
    }

    private func filterButton(_ title: String, favorites: Bool) -> some View {
        let count = history.matching(query, favoritesOnly: favorites).count
        return Button {
            selectTab(favorites ? .favorites : .all)
        } label: {
            HStack(spacing: 4) {
                if favorites { Image(systemName: "star.fill").font(.system(size: 9)) }
                Text(L10n.text(title)).font(.system(size: 11, weight: .medium))
                Text("\(count)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.primary.opacity(0.045), in: Capsule())
            }
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(favoritesOnly == favorites ? accent : .secondary)
            .padding(.horizontal, 7).padding(.vertical, 4)
            .background {
                if favoritesOnly == favorites {
                    if reduceMotion {
                        Capsule().fill(accent.opacity(0.09))
                    } else {
                        Capsule().fill(accent.opacity(0.09))
                            .matchedGeometryEffect(id: "filterSelection", in: filterHighlight)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .animation(navigationAnimation, value: selectedTab)
        .help(L10n.text("Swipe between tabs"))
        .accessibilityLabel("\(L10n.text(title)) \(count)")
        .accessibilityAddTraits(favoritesOnly == favorites ? .isSelected : [])
    }

    private func row(_ entry: ClipEntry) -> some View {
        let selected = selection.selectedID == entry.id
        let hovered = hoveredID == entry.id
        return HStack(spacing: 4) {
            Button { onPaste(entry) } label: {
                HStack(alignment: .center, spacing: 10) {
                    SourceAppIcon(entry: entry)
                    if entry.image != nil && settings.compactLayout {
                        ImageThumbnailView(entry: entry, history: history, compact: true)
                            .frame(width: 40)
                    }
                    VStack(alignment: .leading, spacing: settings.compactLayout ? 4 : 7) {
                        if entry.image != nil && !settings.compactLayout {
                            ImageThumbnailView(entry: entry, history: history)
                        }
                        Text(verbatim: entryDescription(entry))
                            .font(.system(size: 12))
                            .lineLimit(settings.compactLayout ? 1 : 2)
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        HStack(spacing: 4) {
                            Text(verbatim: entry.sourceName ?? L10n.text(entry.image == nil ? "Text" : "Image"))
                                .lineLimit(1)
                            Text("·")
                            Text(entry.copiedAt, format: .dateTime.hour().minute()).lineLimit(1)
                        }
                        .font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                    if !settings.compactLayout {
                        Image(systemName: "return")
                            .font(.system(size: 10, weight: .medium)).foregroundStyle(accent)
                            .opacity(hovered || selected ? 1 : 0).accessibilityHidden(true)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(L10n.text("Paste this item"))
            .accessibilityLabel(L10n.text("Paste") + ": " + entryDescription(entry))
            .accessibilityAddTraits(selected ? .isSelected : [])
            Button {
                history.setFavorite(!entry.isFavorite, id: entry.id)
            } label: {
                Image(systemName: entry.isFavorite ? "star.fill" : "star")
                    .font(.system(size: 12))
                    .foregroundStyle(entry.isFavorite ? accent : .secondary.opacity(0.65))
                    .frame(width: 24, height: 30).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!entry.isFavorite && !history.canAddFavorite)
            .help(L10n.text(!entry.isFavorite && !history.canAddFavorite ? "Favorites limit" : entry.isFavorite ? "Remove favorite" : "Add favorite"))
            .accessibilityLabel(L10n.text(entry.isFavorite ? "Remove favorite" : "Add favorite") + ": " + String(entryDescription(entry).prefix(60)))
        }
        .padding(.horizontal, 11)
        .padding(.vertical, settings.compactLayout ? 8 : 12)
        .background {
            RoundedRectangle(cornerRadius: 10).fill(surface)
            RoundedRectangle(cornerRadius: 10)
                .fill(accent.opacity(selected ? 0.09 : hovered ? 0.035 : 0))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(selected ? accent.opacity(0.33) : .primary.opacity(0.045))
        }
        .onHover { hoveredID = $0 ? entry.id : nil }
        .contextMenu {
            Button(L10n.text("Preview")) { showPreview(entry) }
            Button(L10n.text(entry.isFavorite ? "Remove favorite" : "Add favorite")) {
                history.setFavorite(!entry.isFavorite, id: entry.id)
            }
            .disabled(!entry.isFavorite && !history.canAddFavorite)
            Button(L10n.text("Paste")) { onPaste(entry) }
            Button(L10n.text("Copy")) { onCopy(entry) }
            Button(L10n.text("Delete"), role: .destructive) { history.remove(id: entry.id) }
        }
    }

    private func selectTab(_ tab: HistoryTab) {
        guard tab != selectedTab else { return }
        pasteService.cancel()
        isNavigatingHistory = false
        // Replace the data immediately; animate only the incoming list and tab highlight.
        selectedTab = tab
    }

    private func navigateTabs(_ offset: Int) {
        guard previewEntry == nil && !showingSettings,
              let tab = selectedTab.neighbor(by: offset) else { return }
        selectTab(tab)
    }

    private func showPreview(_ entry: ClipEntry) {
        guard previewEntry == nil && !showingSettings else { return }
        pasteService.cancel()
        selection.select(entry.id, in: resultIDs)
        previewEntry = entry
    }

    private func closePreview() {
        previewEntry = nil
    }

    private func entryDescription(_ entry: ClipEntry) -> String {
        if let image = entry.image {
            return L10n.text("Image") + " · \(image.width) × \(image.height)"
        }
        return entry.preview
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            if query.isEmpty && !favoritesOnly {
                ClipmioMark().frame(width: 76, height: 76).padding(.bottom, 6)
            } else {
                Image(systemName: favoritesOnly && query.isEmpty ? "star" : "magnifyingglass")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(accent.opacity(0.6))
                    .padding(.bottom, 12)
            }
            Text(L10n.text(favoritesOnly && query.isEmpty ? "No favorites yet" : query.isEmpty ? "A fresh clipboard." : "No matches yet."))
                .font(.system(size: 14, weight: .medium))
            Text(L10n.text(favoritesOnly && query.isEmpty ? "Favorites explanation" : query.isEmpty ? "Copy some text to get started." : "Try a different word or app name."))
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 22)
            .frame(height: 32)
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
                             onPaste: { _ in }, onCopy: { _ in }, onDismiss: {}, onRestart: {}, onPreviewChange: { _ in })
    }
}
