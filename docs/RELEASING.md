# Release notes for maintainers

Author: tonngyou · <https://github.com/tonngyou>

## Local builds

`bash scripts/build.sh` produces an ad-hoc-signed `.app` and ZIP for local use. The build script validates the app bundle and fails on verification errors. It does not submit software to Apple or upload anything to GitHub.

## Before a public release

1. Update the marketing/build versions. Run `swift test`, build Release, and complete the manual checks below.
2. Choose your own Developer ID Application certificate. No other developer's identity or keys are included.
3. Sign with hardened runtime and a secure timestamp, submit the app archive with `xcrun notarytool`, wait for acceptance, and staple the ticket to the app. Re-create the downloadable archive after stapling.
4. Verify the signature and Gatekeeper acceptance on a Mac that did not build the app. Test the actual browser-downloaded archive, not just the local build folder.
5. When ready, create your own public GitHub repository and publish the source, license, release notes, archive, and SHA-256 checksum. Never commit certificates, API keys, real history, or private clipboard samples.

Apple references:
- https://developer.apple.com/developer-id/
- https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution

## Manual acceptance

- Fresh launch: menu icon appears; copying after launch adds text.
- From another app, Cmd+Shift+V opens history and focuses search. Press again to dismiss and return to the previous app; reopen with the old query cleared.
- If another app owns Cmd+Shift+V, show an unavailable notice and keep the menu-bar entry working. After the owner quits, Retry Shortcut succeeds. Quitting Clipmio releases the registration.
- Chinese, English, multiline text and whitespace survive copy-back unchanged.
- Copy a screenshot, a browser image, and a single PNG/JPEG file in Finder. Confirm thumbnail, dimensions, source and restart persistence. Copy back into an image-capable app; verify original pixels and transparency. PNG and TIFF representations should be available on the pasteboard.
- Search for 图片/image and for the source app. Removing the source file must not break the saved image. Deleting/evicting an image or clearing history should clean its managed file; paused/private pictures stay excluded.
- Copy A, B, A: only A and B remain, with A first. At most 50 records survive.
- Search matches content and source; plain Up/Down select within filtered results and stop at the ends. A new query selects the first match. The selected row scrolls into view.
- Space on a selected record opens a larger preview. Text is complete/selectable and retains line breaks; image zoom and Fit work. Space/Escape returns to the same query and selected record and focuses search. Merely previewing must not copy/paste. A held Space must not toggle repeatedly. Space while typing a query remains text unless arrow navigation has selected a record; IME composition and modifier shortcuts must remain intact.
- Return pastes the selected item (not always the first result). Chinese/Japanese marked text keeps Up/Down/Return for input-method composition; modified arrow keys retain normal text-editing behavior.
- Image click/Return: once copied and input keys are released, close the panel and restore the previous app even without Accessibility permission. Image paste failures must not reopen the panel; instructions are retained for the next manual opening. Arrow-only browsing keeps the panel open; copy failures keep the panel open.
- Without Accessibility permission, text is copied and instructions remain in the panel. For an image, instructions appear on the next manual opening. The Enable Automatic Paste button opens settings; permission is never enabled programmatically.
- With permission, Return/click waits for key release, closes the popover, returns to the original app, and posts Command-V to its process. Confirm exact text in a new, disposable document in Notes or TextEdit.
- Right-click Copy remains available without Accessibility permission. Escape clears the query, then dismisses the panel and returns to the previous app.
- Switching away, quitting the target, changing the clipboard, or reopening history during a pending paste must not send a stale paste.
- A paused copy stays excluded after resume. Marked private clipboard data stays excluded.
- Delete and clear survive restart. Clearing history leaves the current system clipboard unchanged.
- Restart restores history; Debug and Release do not share history. Demo never writes a history file.
- Confirm light/dark appearances, narrow menu bar positioning, and Simplified Chinese/Traditional Chinese/English UI.
- Confirm history is local, with file permissions 0600. Do not claim encryption or universal password detection.
- On unreadable storage, show an error and retain the original file.
