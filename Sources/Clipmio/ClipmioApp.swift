// Copyright (c) 2026 tonngyou. MIT License.
import SwiftUI

@main
struct ClipmioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Settings { EmptyView() }
            .commands {
                // Keep the native field editor's Cut/Copy/Paste/Select All commands.
                TextEditingCommands()
                CommandGroup(replacing: .appSettings) {}
            }
    }
}
