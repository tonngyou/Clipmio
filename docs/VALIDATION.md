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


## Hang recovery and lifecycle controls (0.1.2)

- Observed the installed 0.1.1 process alive at roughly 97% CPU. A three-second sample showed the main thread continuously flushing SwiftUI layout transactions, including lazy-layout phase, scroll and alignment calculations. Diagnostic: build/hang-0.1.1.sample.txt (local, ignored). This establishes a layout hang; the exact triggering sequence has not been reproduced.
- Terminated only the identified Clipmio process and relaunched the installed app; CPU returned to approximately zero. No history was cleared.
- Replaced the history's lazy stack with a regular stack bounded by the existing 50-entry capacity. Limited card summaries to 400 Unicode characters before newline normalization, so a two-line card no longer lays out an entire clipboard payload. Full text is retained for storage, search, detail preview and copy. Native search placeholder/accessibility values are set only when changed, avoiding redundant native layout invalidation.
- Added an AppKit status-button right-click / Control-click menu with history, pause/resume, restart and quit. The SwiftUI more-options menu also includes restart. Restart cancels pending paste, stops monitoring, releases the hotkey, launches a fresh instance and quits the original only after launch succeeds; failure restores services and reports an error. These controls still require a responsive main thread; a full-process hang requires macOS Activity Monitor.
- swift test: 70 tests passed (50 app, 20 core), including a large Unicode text regression confirming bounded summaries and unchanged full text/search. Logs: build/tests-recovery.log. Native arm64 Debug and universal Release builds and strict signature checks passed; logs: build/debug-recovery.log and build/release-recovery.log.
- Actual Debug demo rendered 50 long multiline Unicode records and stayed at low idle CPU. The more-options menu exposed Restart and Quit. Clicking Restart changed the demo PID from 29801 to 29841 and exited the old process, preserving demo mode. A subsequent automated scroll/preview attempt could not be verified because computer-use window targeting timed out; the tested process remained idle (0% CPU), rather than showing the original layout hang. No claim is made that the original hang can never recur.
- Stopped test instances and the old installed app, backed up the previous bundle to build/Clipmio-before-recovery-0.1.1.zip, installed /Applications/Clipmio.app 0.1.2 (build 3) and reopened it. Verified history.json remained byte-for-byte unchanged and the installed signature is valid. Package: dist/Clipmio-0.1.2.zip. No system login-item or security permission changes were made; the existing public GitHub release remains 0.1.1.


## Dock context-menu Quit (0.1.2 build 4)

- Implemented NSApplicationDelegate.applicationDockMenu using the existing localized Quit Clipmio title, targeting NSApplication.terminate(_:). The Dock can display this command without opening the history popover. Activation policy and login settings are unchanged.
- Universal arm64/x86_64 Release build and strict signature validation passed. Log: build/release-dock-quit.log. No new implementation-mirroring tests were added for this small menu wiring change.
- The Dock computer-use surface timed out, so the final Dock popup was not visually verified. Backed up build 3 to build/Clipmio-before-dock-quit-build3.zip, installed build 4 and relaunched /Applications/Clipmio.app. Verified the history index was unchanged. The existing public GitHub release was not modified.


## Correct Dock application lifecycle (0.1.3 build 5)

- Follow-up user report confirmed that the previous custom menu did not appear in the Dock. The app was still LSUIElement=true and explicitly used accessory activation policy, inconsistent with the requested normal Dock behavior. Confirmed the pinned Dock tile points to /Applications/Clipmio.app.
- Changed LSUIElement to false and activation policy to regular. Manual launches open the history popover; Dock reopen brings it back. Login/service launch Apple events and explicit --background launches suppress automatic presentation. Restarts use --background. Demo data and clipboard monitoring remain gated only by --demo.
- The custom Dock menu now offers history and restart, leaving Quit to macOS's built-in standard command for regular applications. No forced bounce / repeated attention animation is requested.
- Added two startup-policy tests using actual Apple event descriptors for login and service launch reasons. swift test: 72 tests passed (52 app, 20 core). Universal Release build, strict signature check and Info.plist lint passed. Logs: build/tests-dock-lifecycle.log and build/release-dock-lifecycle.log.
- Installed 0.1.3, re-registered only the installed bundle with Launch Services, and preserved the existing history index byte-for-byte. Runtime NSRunningApplication metadata confirmed activationPolicy=0 (regular), launched=true; the installed plist has LSUIElement=false.
- Actual app inspection showed the history popover opened on manual launch. The standard application menu displayed Quit Clipmio (terminate:); clicked it, confirmed the old installed process exited, and reopened the app successfully as one fresh process. The Dock computer-use target still timed out, so visual verification of the Dock context menu and launch animation remains unverified. Normal system launch animation depends on macOS and is not expected on every click of an already-running app.


## Stability regression (0.1.4 build 6, 2026-10-22)

- Debug and Release test suites each passed all 75 tests (53 app, 22 core), including three new stress regressions for near-limit Unicode persistence, mixed image rollover/cleanup and cancellation during rapid clipboard changes.
- Native Debug and universal Release builds passed. Verified arm64/x86_64, strict signature and Info.plist; the only Release build warning was skipped App Intents extraction because the app has no AppIntents dependency.
- Actual isolated demo checks passed for repeated long-list scrolling, search/preview/return, immediate language change with preserved search, image zoom/Fit, restart and native menu Quit.
- Fixed startup presentation to use idempotent showHistory rather than togglePopover, avoiding closing a panel already shown by a reopen event. Installed and launched 0.1.4 with an application-bundle backup and byte-identical history fingerprints across replacement.
- Full report, evidence paths and coverage limits: [STABILITY-REGRESSION.md](STABILITY-REGRESSION.md). No GitHub push or Release was performed.


## Compact layout, source icons, favorites and configurable shortcut (0.2.0 build 7)

- Added a compact layout enabled by default, with a smaller header, one-line summaries, small image thumbnails and 52-point minimum cards. Settings can switch back to two-line cards and larger image thumbnails. The history panel is now 400 × 520 points.
- Replaced row type placeholders with locally resolved source application icons. New text and image captures preserve sourceBundleID; legacy source names resolve through running apps or local application folders, with a content-type fallback. Icon lookups are cached.
- Favorites retain their identity and state on recopy, persist across restart, and do not compete with the 50 recent clips. A separate 50-favorite allocation keeps the view bounded at 100 entries. Clear Recent History keeps favorites and their image attachments; individual deletion remains available. Legacy JSON without the new fields loads normally.
- Added a native first-responder shortcut recorder in Settings, persistent validated combinations, dynamic labels, default reset, conflict handling and restoration on cancel/focus loss. Recording suspends the old registration; direct changes try the new registration before releasing a working old registration. No event tap or new security permission is required. Errors also update when the interface language changes.
- Debug and Release suites each passed 85 tests (59 app, 26 core), including ten additional tests for migration, favorite text/image retention and attachment cleanup, limits, source metadata, shortcut replacement/conflict/rollback, input validation, settings persistence and leaving the recording window. Logs: build/features-tests.log and build/features-release-tests.log.
- Native Debug and arm64/x86_64 Release builds passed, with strict signature verification, Info.plist lint and git diff --check. Logs: build/features-debug.log and build/features-release.log.
- Actual isolated demo UI checks passed: local Notes/Terminal/Safari/Preview icons, compact and expanded layout, add/remove favorites and empty state, mixed text/image favorites, favorite search and full image preview, recording a new combination, rejecting unmodified typing, Escape cancellation, leaving settings while recording, conflict on restoring the occupied default and immediate Chinese translation of the error. The installed app retained the default shortcut during demo testing; live physical global key dispatch outside the app was not separately verified.
- Backed up the old application to build/Clipmio-before-features-0.1.4-build6.zip, installed and launched /Applications/Clipmio.app 0.2.0 (7), and verified all installed history file fingerprints were unchanged across bundle replacement. Demo preferences and history were isolated. No login item or Accessibility permission was changed.
- Local package: dist/Clipmio-0.2.0.zip; ad-hoc signed and not notarized. GitHub was not pushed or released in this task. Earlier limits for physical Dock menu, real reboot and cross-application paste checks still apply.


## Per-tab counts (0.2.1 build 8)

- Moved the shared result-count badge into each filter button. All and Favorites now independently count entries matching the current query, including zero, and expose their label/count as an accessible button.
- Universal Release build, strict signature validation, Info.plist lint and git diff --check passed. Log: build/tab-counts-release.log. This presentation-only change adds no new tests; existing matching logic is unchanged.
- Verified the installed UI shows All 6 / Favorites 0, retains All 6 when viewing empty Favorites, shows All 1 / Favorites 0 when searching, and returns to All 6 / Favorites 0 after clearing search. The live total includes the newest screenshot copied by the user.
- Installed 0.2.1 and preserved history files across replacement. Previous 0.2.0 bundle backup: build/Clipmio-before-tab-counts-0.2.0-build7.zip.


## SwiftUI navigation animation (0.2.2 build 9)

- Added a matchedGeometryEffect capsule for All/Favorites, with a 0.24-second smooth animation and keyed list fade/short directional offset. Only the results region is replaced, preserving the search field and query.
- Added ZStack transitions for history, details and settings. Detail insertion uses opacity, a small horizontal offset and 0.985 scale; return fades and slides back. Each page retains its fixed content size; NSPopover handles the anchored size animation through contentSize. No manual window-frame animation is used.
- accessibilityReduceMotion switches SwiftUI transitions to a short opacity fade and removes the moving capsule. NSPopover.animates follows NSWorkspace.accessibilityDisplayShouldReduceMotion on presentation and resize. System accessibility preferences were not changed during testing; this branch was checked in source.
- Added live activity guards to the search and preview keyboard handlers so outgoing views retained for transitions cannot consume space/escape/return or submit another paste. Two regression tests cover routing after a view becomes inactive.
- swift test passed all 87 tests (61 app, 26 core); native Debug and universal arm64/x86_64 Release builds, strict signature validation, Info.plist lint and git diff --check passed. Logs: build/motion-tests.log, build/motion-debug.log, build/motion-release.log. No separate optimized SwiftPM test run was performed for this version.
- Exercised actual isolated demo UI flows for All/Favorites with a saved favorite, text preview and return, repeated Space return/reopen, image search/preview/return and query/count/selection preservation. Screenshot dimensions returned to the normal 852 × 1092 capture from the detail 1332 × 1252 capture at 2x. Static captures establish final layout and navigation behavior, not frame-by-frame timing quality.
- Quit the demo; backed up the prior installed app to build/Clipmio-before-motion-0.2.1-build8.zip; installed and launched /Applications/Clipmio.app 0.2.2 (9). Saved history file fingerprints were unchanged across replacement. Local package: dist/Clipmio-0.2.2.zip. No GitHub publication or system permission changes were made.


## Incoming-only motion and horizontal tab navigation (0.2.3 build 10)

- Replaced overlapping page/list transitions with a single current page and an incoming-only 0.16-second opacity/6-point offset animation. Outgoing content is removed immediately. Kept the sliding tab highlight. The detail panel changes size once with NSPopover size animation disabled, avoiding simultaneous SwiftUI and AppKit resize/snapshot animations. Reduce Motion uses a short fade. Static screenshots verify final layout, not frame-by-frame smoothness on every display.
- Added mouse-left-button horizontal dragging in the heading/list region through a high-priority SwiftUI drag gesture, plus a local NSEvent monitor for horizontal scroll/swipe events and mouse back/forward buttons. Search, settings and preview panning are outside the active gesture region. No global event tap or new permission is used.
- Direction recognition locks onto a clear horizontal or vertical axis, applies a threshold, selects at most one tab per gesture, ignores momentum navigation and stops at both ends. Phase-less mouse-wheel ticks are grouped until idle; Shift+vertical wheel can be treated as horizontal.
- Added nine input-behavior tests for mouse drag direction/threshold, vertical and diagonal movement, momentum, cancellation/end, phase-less wheel grouping, duplicate swipe events and tab boundaries. Full swift test passed 96 tests (70 app, 26 core), with zero failures/skips. Native Debug and universal arm64/x86_64 Release builds, strict signature validation, Info.plist lint and git diff --check passed. Logs: build/swipe-tests.log, build/swipe-debug.log, build/swipe-release.log.
- Actual isolated demo checks with direct screen-coordinate interaction passed: drag left from All to empty Favorites, drag right back to All, ordinary star-button clicking after drag support, clicking between populated tabs, text preview and Escape return with preserved tab/selection. Native scrolling events were observed reaching the correct window and gesture bounds. The automation tool emitted mixed-axis scrolling sequences and timed out, so physical touchpad/Magic Mouse scrolling and side-button behavior are not claimed as end-to-end verified. Temporary event diagnostics were removed.
- During an earlier accessibility-driven click attempt, the tool selected a demo record and wrote demo text to the system clipboard. No history was cleared and no target paste was sent (the app reported no destination). The pre-test clipboard was not captured, so no guessed restoration was attempted. Demo copy/paste handlers now return before touching the real clipboard, in addition to the existing in-memory history and disabled monitoring/preferences/login-item writes.
- Stopped all demo instances, backed up the installed 0.2.2 bundle to build/Clipmio-before-swipe-0.2.2-build9.zip, and installed/launched /Applications/Clipmio.app 0.2.3 (10). All saved history file fingerprints were unchanged across bundle replacement; this does not assert that the live history was unchanged for the entire testing session. Local package: dist/Clipmio-0.2.3.zip. No GitHub publication or system permission changes were made.


## Keyboard left/right tab navigation (0.2.4 build 11)

- Added unmodified Left/Right and the native text-system moveBackward/moveForward aliases to the active search-field coordinator. Empty search switches All/Favorites; nonempty search keeps cursor movement until Up/Down explicitly enters history browsing. Keyboard tab switches preserve browsing mode, so repeated Left/Right continues to work while retaining the query. Existing neighbor logic stops at tab boundaries.
- Uses the live field-editor string for routing, preserving IME marked text, selection/word movement modifiers and inactive-page behavior. Mouse switching retains its existing mode behavior. Added localized footer hints and tab help.
- Added four behavioral tests for empty-search routing/aliases, search editing versus browsing, IME/modifier/inactive pass-through and stale-binding versus live-editor text. Full swift test passed 100 tests (74 app, 26 core), zero failures/skips. Native Debug and universal Release builds, strict signature validation, Info.plist lint and git diff --check passed. Logs: build/keyboard-tabs-tests.log, build/keyboard-tabs-debug.log, build/keyboard-tabs-release.log.
- Actual isolated demo keyboard checks passed: Right selects Favorites and Left returns to All; entering Notes while in Favorites preserves the tab on Left; Down then Left selects All 2 with the query intact; subsequent Right/Left continues switching with the query intact. No clipboard writes or target pastes were used in these checks. IME composition/modifier cases were checked by tests, not by changing the user's input method.
- Stopped the demo, backed up 0.2.3 to build/Clipmio-before-keyboard-tabs-0.2.3-build10.zip, installed and launched /Applications/Clipmio.app 0.2.4 (11). All history-file fingerprints matched across replacement. Local package: dist/Clipmio-0.2.4.zip. No GitHub publication or system permission changes were made.
