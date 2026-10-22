// Copyright (c) 2026 tonngyou. MIT License.
import AppKit
import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let loginItem: LoginItemManager
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: onClose) {
                    Label(L10n.text("Back to history"), systemImage: "chevron.left")
                }
                .buttonStyle(.plain)
                Spacer()
                Text(L10n.text("Settings")).font(.headline)
            }
            .padding(20)
            Divider()
            Form {
                Section {
                    Picker(L10n.text("Language"), selection: $settings.language) {
                        Text(L10n.text("Follow System")).tag(AppLanguage.system)
                        Text(verbatim: "简体中文").tag(AppLanguage.simplifiedChinese)
                        Text(verbatim: "繁體中文").tag(AppLanguage.traditionalChinese)
                        Text(verbatim: "English").tag(AppLanguage.english)
                    }
                    Text(L10n.text("Language changes immediately"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    Toggle(L10n.text("Launch at login"), isOn: Binding(
                        get: { loginItem.state.isRequested },
                        set: { loginItem.setEnabled($0) }))
                        .disabled(!loginItem.canManage)
                    Text(L10n.text("Launch at login explanation"))
                        .font(.caption).foregroundStyle(.secondary)
                    if !loginItem.canManage {
                        Text(L10n.text("Login item install notice"))
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        if loginItem.state == .requiresApproval {
                            Text(L10n.text("Login item approval notice"))
                                .font(.caption).foregroundStyle(.orange)
                        }
                        if loginItem.state == .unavailable {
                            Text(L10n.text("Login item unavailable notice"))
                                .font(.caption).foregroundStyle(.orange)
                        }
                        if loginItem.changeFailed {
                            Text(L10n.text("Login item failed notice"))
                                .font(.caption).foregroundStyle(.orange)
                        }
                        Button(L10n.text("Open Login Items Settings")) { loginItem.openSettings() }
                            .font(.caption)
                    }
                }
            }
            .formStyle(.grouped)
            Spacer(minLength: 0)
        }
        .onAppear { loginItem.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            loginItem.refresh()
        }
        .onExitCommand(perform: onClose)
    }
}
