# Clipmio 0.1.0 validation

Checked on 2026-10-22 using Xcode 27.1 / Swift 6.4 on an Apple Silicon Mac.

- `swift test`: **12 tests passed** (8 history/persistence/policy tests, 4 actual named-pasteboard monitor tests). All tests use temporary storage and isolated named pasteboards, not the user's history or general clipboard.
- Xcode Debug build: passed.
- Xcode Release build: passed, arm64.
- Ad-hoc bundle signature: `codesign --verify --strict` passed.
- Bundle metadata: `plutil -lint` passed.
- Runtime: launched the actual app bundle with in-memory demo records.
- UI checks: Simplified Chinese and English text, light and dark appearances, Chinese filtering, source-name search, empty results, Cmd+A and Cmd+V in search, menu actions and About panel author/link.
- Checked that exiting the demo terminates its process. No demo monitor or demo history file is left running.

The build emits Xcode's informational AppIntents metadata warning because this application does not use AppIntents. There were no Swift compilation warnings in the final build.

Not verified: Intel runtime, macOS 14 runtime, public-download Gatekeeper acceptance, Apple notarization, App Store review, or GitHub Actions on a remote repository. Public publishing is not part of this build. Later feature checks are recorded below.

The built ZIP is for local testing and has an ad-hoc signature, not a Developer ID signature.

## Global shortcut update

- `swift test`: **15 tests passed**, including three real Carbon registration/dispatch tests using an isolated test key combination. They cover exclusive ownership, conflict recovery, unregistering, event identity, and ignoring release events.
- Native Xcode Debug and Release builds passed; the local app and ZIP were rebuilt.
- The actual demo app reports successful registration of `⌘⇧V`, and the search field receives focus when opened.
- The UI automation keyboard injector did not deliver system hotkey notifications, so a physical cross-application key press still needs a manual check. The Carbon callback itself is exercised by the event-dispatch tests.
- No Accessibility or Input Monitoring access is used. The test app was exited after verification.

## Keyboard selection and automatic paste update

- `swift test`: **33 tests passed**. New tests cover selection bounds, selection after filtering/removal, native text-command routing, preserving input-method composition, and the asynchronous paste workflow.
- Paste tests inject system dependencies: they do not request Accessibility access, post keystrokes to real apps, or replace the general clipboard. The paired Command-V event objects are checked without posting them.
- Workflow checks include waiting for Return/modifier release before dismissal, stable target focus, denied/revoked permission, missing/terminated targets, clipboard changes, focus changes/timeouts, and cancellation while waiting.
- The actual demo app showed a highlighted record and moved the selection on Down. Typing a search filtered the results and selected the first match; Escape cleared it and restored the first history selection. Search keeps the native field editor and standard text-editing shortcuts.
- Native Debug/Release builds and the local ad-hoc app bundle were checked. The packaged app and ZIP include the update.
- End-to-end insertion into another application remains a manual acceptance check after the user grants Accessibility to the exact running build. No security permission was enabled by the assistant.

## Clipmio identity and SwiftUI update

- Replaced the initial close reconstruction of the supplied ClipLite reference with a newly generated transparent Clipmio logo: layered lavender sheets, a curled page corner and an M-shaped ribbon clasp. The PNG is embedded in both native and SwiftPM resources; the same artwork is packaged as the app's ICNS. The menu bar uses a corresponding simplified template drawing.
- Moved the entry point to SwiftUI `App` with `NSApplicationDelegateAdaptor`. SwiftUI owns the card list, search container, menus, empty state and light/dark theme. AppKit continues to bridge the status item, popover, input-method-aware field editor and cross-app focus. SwiftUI `TextEditingCommands` supplies standard editing commands.
- `swift test`: **33 tests passed** (22 app-system tests and 11 core tests), including the existing input-method, keyboard, hotkey and paste-workflow coverage. Logs: `build/tests-original.log`.
- Native Debug and Release builds passed. Release app signature verification and Info.plist lint passed; the app and ZIP in `dist/` were rebuilt. Logs: `build/debug-original.log`, `build/release-original.log`.
- Actual app checks: new logo visible in Simplified Chinese light UI and English dark UI; Down changes selected record; Chinese search filters to one result; Command-A replaces the full query; an unmatched query shows the empty state; Escape restores the list. The About panel displays the new icon and tonngyou credits. Updated screenshots in `docs/` show the actual app, using in-memory demo data.
- The first resource lookup through SwiftUI's named image did not display the loose PNG in the native bundle. Loading its exact bundle URL into `NSImage` fixed this; final screenshots and About-panel checks confirm it is visible.
- No Accessibility permission was enabled. The limitations for physical global-shortcut and real cross-app paste checks recorded above still apply. This remains a locally signed build, not a notarized public release.

## Image history update

- Added backward-compatible image metadata to entries; the old text-only JSON format still loads. Image bytes live in private `Images/<SHA-256>.png` files beside the history index, rather than base64 in JSON. In-memory demo history keeps its images in memory only.
- Captures PNG, TIFF, JPEG and system-supported HEIC/HEIF clipboard images, plus a single local image file copied as a file URL. URL-only website links, remote file hosts, animation and multiple-file imports are outside this version's image support. The file importer reads only supported image formats, with size checks.
- Conversion and thumbnail decoding run off the main actor. A clipboard change, pause, own-copy action or stop cancels pending capture. Images take priority over accompanying URL/text representations. Images and text share the 50-entry limit; exact PNG recopy preserves the entry ID.
- Copy-back writes PNG and TIFF representations. Text and images use the same guarded automatic-paste workflow. No Accessibility permission is needed for right-click Copy; automatic paste still requires the user to grant it.
- `swift test`: **50 tests passed**: 32 app tests and 18 core tests. The new checks cover private named pasteboards, PNG/TIFF handling, pixel/alpha round-trip, JPEG/file import, original-file deletion, remote/non-image rejection, stale/cancelled capture, private/paused images, image paste payloads, legacy history, image persistence, file permissions, eviction/deletion/clear, missing/tampered attachments, invalid metadata and unreadable-index preservation. Logs: `build/tests-images.log`.
- Native Debug build passed. The actual demo UI displayed the image thumbnail, dimensions and source, and searching 图片 returned the selected image. Screenshot: `docs/screenshot.images.png`.
- Final native Release build, bundle signature verification and Info.plist lint passed; `dist/Clipmio.app` and the ZIP contain the image update. The packaged Release app was launched in demo mode and displayed the image in dark mode when searching image. Screenshot: `docs/screenshot.images-dark.png`. Test demo processes were exited after inspection.
- Images are limited to 10 MiB after PNG normalization, 32 million pixels and 16384 pixels per edge; raw input is limited to 64 MiB. Unsupported, corrupt or oversized images are skipped. The image tests use generated fixtures and temporary storage; they do not copy into real documents or use the general pasteboard.
- Real insertion into other apps, physical global shortcut presses, Intel runtime and macOS 14 runtime remain manual acceptance checks. No security permission was enabled during this update.

## Close the panel after choosing an image

- Image click/Return copies the image, waits for held input keys to release, closes the popover and restores the target app. This also closes when Accessibility permission is missing or the target no longer exists. A failed image copy keeps the panel open.
- Automatic-paste failures after image selection no longer reopen the popover. The stored failure appears on the next manual opening; an Accessibility hint is cleared once permission is available. Text paste retains its existing failure/reopen behavior. Arrow-key browsing by itself does not close the panel.
- `swift test`: **54 tests passed** (36 app tests, 18 core tests). Tests cover denied image-paste permission with target restoration, no target, copy failure, held Return, suppressed reopening after image failure, retained/deferred failure hints, permission recovery, and the existing text failure behavior. Tests inject OS boundaries and do not manipulate the user's running app, clipboard or documents. Log: `build/tests-dismiss-image.log`.
- Native Debug build passed. The user had an Xcode-launched Clipmio instance running in a different DerivedData folder; that instance was left running. It needs to be stopped and run again to pick up the changed sources. No Accessibility permission was enabled.
- Final Release build, strict bundle signature verification and Info.plist lint passed. The rebuilt app and ZIP in `dist/` contain the change. Log: `build/release-dismiss-image.log`.

## Space-bar detail preview

- Added a SwiftUI detail view inside the existing popover. Space opens the selected text/image in a wider panel. Original text remains selectable and scrollable with its line breaks preserved; image preview supports zoom, pan/scroll and Fit. Source/time and image dimensions/file size or text character count are visible. Space/Escape returns to the existing query and selected row; Return and the explicit Copy/Paste buttons use the existing guarded operations.
- Search spaces remain ordinary text until arrow navigation selects a result (empty search can preview immediately). Local window-scoped key monitors preserve IME composition, modifier shortcuts and other windows. Key repeats are consumed without repeatedly toggling preview. Monitors are removed when their represented views are dismantled. An eye button and right-click Preview provide mouse access.
- Large preview decoding runs off the main actor and is capped at 4096 pixels per edge; stored image bytes are unchanged. Preview does not generate temporary preview files or require permissions.
- `swift test`: **62 tests passed** (43 app tests, 19 core tests). New checks cover empty-search Space, search whitespace, navigation intent, no selection, IME/modifier pass-through, repeat handling, preview close/Return routing, explicit selection validity, and requested image preview resolution. Logs: `build/tests-preview.log`.
- Native Debug and Release builds passed; strict signature and Info.plist validation passed; the app and ZIP were rebuilt. Logs: `build/debug-preview.log`, `build/release-preview.log`.
- Actual packaged demo checks: full multiline text preview; Escape restores search focus; filtered image + Down + Space opens the correct image; Zoom and Fit work; Space returns with the original 图片 query and selected image; typing Keep followed by Space remains a search query rather than opening preview. English dark-mode preview was also inspected. No preview Copy/Paste actions or permission changes were performed.
- Screenshots: `docs/screenshot.preview-text.png`, `docs/screenshot.preview-image.png`, `docs/screenshot.preview-dark.png`. Only demo instances created for inspection were stopped; the user's Xcode-launched instance was left running.


## Language selection and launch at login (0.1.1)

- Added an in-panel Settings page under the more-options menu. System, Simplified Chinese, Traditional Chinese and English choices use the existing string resources and take effect immediately; the locale also updates date formatting. The native search field refreshes its placeholder and accessibility label. Language selection is persisted in app preferences; history text is unchanged.
- Login items use SMAppService.mainApp, with no automatic registration at launch. Enabled, disabled, approval-pending and unavailable states come from macOS. Failed changes keep the actual service state, pending registrations can be cancelled, and returning from System Settings refreshes status. The setting controls launch after user login, with no automatic history popover.
- swift test: 69 tests passed (50 app, 19 core). Seven new tests cover persistent language choice, invalid preference fallback, explicit translations, locale-key parity, registration/unregistration, pending approval/cancellation, external status changes, failed changes and preview isolation. Tests use a fake login-item service and isolated UserDefaults; no system login item was registered or removed. Log: build/tests-settings.log.
- Native arm64 Debug and universal arm64/x86_64 Release builds passed. Strict signature checks, Info.plist lint and both architecture checks passed. Logs: build/debug-settings.log and build/release-settings.log.
- Actual Debug demo UI: opened Settings, switched to Simplified Chinese and back to English; labels and native search placeholder changed immediately. A Keep search remained intact after opening Settings and changing language. The demo login toggle was disabled. No real clipboard operations or security grants were performed.
- Quit the demo and previous installed app normally, backed up the previous app in build/Clipmio-installed-before-settings.app, and updated /Applications/Clipmio.app to 0.1.1 (build 2). Verified the installed executable matches dist/Clipmio.app and launched only the installed version. Existing history is preserved. The packaged ZIP is dist/Clipmio-0.1.1.zip.
- Real login/reboot behavior, system approval dialogs and Intel runtime still require manual acceptance. This remains ad-hoc signed and unnotarized. The existing GitHub 0.1.0 release has not been changed.
