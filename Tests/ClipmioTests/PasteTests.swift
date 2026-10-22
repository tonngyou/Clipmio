import AppKit
import Carbon.HIToolbox
import XCTest
@testable import Clipmio

@MainActor
private final class PasteHarness {
    let target: pid_t
    var copied: ClipboardContent?
    var clipboardVersion = 0
    var trusted = true
    var targetAlive = true
    var keysReleased = true
    var shouldActivate = true
    var shouldCopy = true
    var shouldSend = true
    var automaticallyFocus = true
    var frontmost: pid_t? = 1111
    var dismissed = false
    var activationCount = 0
    var sentTo: [pid_t] = []
    var waits = 0
    var onWait: (() -> Void)?

    init(target: pid_t = 4242) { self.target = target }

    var coordinator: PasteCoordinator {
        PasteCoordinator(environment: PasteEnvironment(
            copy: { text in
                guard self.shouldCopy else { return nil }
                self.copied = text
                self.clipboardVersion += 1
                return self.clipboardVersion
            },
            clipboardChangeCount: { self.clipboardVersion },
            isTrusted: { self.trusted },
            targetExists: { $0 == self.target && self.targetAlive },
            inputIsReleased: { self.keysReleased },
            activate: { pid in
                self.activationCount += 1
                if self.automaticallyFocus { self.frontmost = pid }
                return self.shouldActivate
            },
            frontmostPID: { self.frontmost },
            sendPaste: { pid in self.sentTo.append(pid); return self.shouldSend },
            wait: {
                self.waits += 1
                self.onWait?()
                await Task.yield()
                try Task.checkCancellation()
            }
        ), attempts: 4)
    }

    func run(target: pid_t? = 4242, content: ClipboardContent = .text("原始文本\n  keep spaces")) async -> PasteResult {
        await coordinator.perform(content: content, target: target) { self.dismissed = true }
    }
}

final class PasteTests: XCTestCase {
    @MainActor
    func testPasteCopiesExactTextAndWaitsForStableTargetFocus() async {
        let h = PasteHarness()
        let result = await h.run()
        XCTAssertEqual(result, .pasted)
        XCTAssertEqual(h.copied, .text("原始文本\n  keep spaces"))
        XCTAssertTrue(h.dismissed)
        XCTAssertEqual(h.activationCount, 1)
        XCTAssertGreaterThanOrEqual(h.waits, 1)
        XCTAssertEqual(h.sentTo, [h.target])
    }

    @MainActor
    func testDeniedAccessibilityCopiesWithoutClosingOrInjecting() async {
        let h = PasteHarness()
        h.trusted = false
        let result = await h.run()
        XCTAssertEqual(result, .accessibilityRequired)
        XCTAssertNotNil(h.copied)
        XCTAssertFalse(h.dismissed)
        XCTAssertEqual(h.activationCount, 0)
        XCTAssertTrue(h.sentTo.isEmpty)
    }

    @MainActor
    func testMissingTargetAndCopyFailureDoNotSendEvents() async {
        let h = PasteHarness()
        let missing = await h.run(target: nil)
        XCTAssertEqual(missing, .noTarget)
        XCTAssertFalse(h.dismissed)
        h.shouldCopy = false
        let failed = await h.run()
        XCTAssertEqual(failed, .clipboardWriteFailed)
        XCTAssertTrue(h.sentTo.isEmpty)
    }

    @MainActor
    func testHeldReturnIsReleasedBeforeClosingThePopover() async {
        let h = PasteHarness()
        h.keysReleased = false
        h.onWait = {
            if h.waits == 1 {
                XCTAssertFalse(h.dismissed)
                XCTAssertEqual(h.activationCount, 0)
                h.keysReleased = true
            }
        }
        let result = await h.run()
        XCTAssertEqual(result, .pasted)
        XCTAssertEqual(h.sentTo, [h.target])
    }

    @MainActor
    func testModifiersThatStayHeldNeverPasteIntoTheTarget() async {
        let h = PasteHarness()
        h.keysReleased = false
        let result = await h.run()
        XCTAssertEqual(result, .inputNotReleased)
        XCTAssertFalse(h.dismissed)
        XCTAssertTrue(h.sentTo.isEmpty)
    }

    @MainActor
    func testChangedClipboardCancelsInsteadOfPastingAnotherApplicationsContent() async {
        let h = PasteHarness()
        h.onWait = { h.clipboardVersion += 1 }
        let result = await h.run()
        XCTAssertEqual(result, .clipboardChanged)
        XCTAssertTrue(h.sentTo.isEmpty)
    }

    @MainActor
    func testFocusTimeoutDoesNotInjectIntoTheFrontmostApp() async {
        let h = PasteHarness()
        h.automaticallyFocus = false
        let result = await h.run()
        XCTAssertEqual(result, .focusTimeout)
        XCTAssertEqual(h.activationCount, 1)
        XCTAssertTrue(h.sentTo.isEmpty)
    }

    @MainActor
    func testSwitchingAwayAfterActivationDoesNotStealFocusBack() async {
        let h = PasteHarness()
        h.onWait = { h.frontmost = 7777 }
        let result = await h.run()
        XCTAssertEqual(result, .focusTimeout)
        XCTAssertEqual(h.activationCount, 1)
        XCTAssertTrue(h.sentTo.isEmpty)
    }

    @MainActor
    func testTerminatedTargetAbortsPendingPaste() async {
        let h = PasteHarness()
        h.onWait = { h.targetAlive = false }
        let result = await h.run()
        XCTAssertEqual(result, .noTarget)
        XCTAssertTrue(h.sentTo.isEmpty)
    }

    @MainActor
    func testRevokedPermissionIsCheckedAgainBeforeSending() async {
        let h = PasteHarness()
        h.onWait = { h.trusted = false }
        let result = await h.run()
        XCTAssertEqual(result, .accessibilityRequired)
        XCTAssertTrue(h.sentTo.isEmpty)
    }

    @MainActor
    func testCancellingWhileWaitingNeverSendsAPaste() async {
        let h = PasteHarness()
        h.onWait = { withUnsafeCurrentTask { $0?.cancel() } }
        let task = Task { await h.run() }
        let result = await task.value
        XCTAssertEqual(result, .cancelled)
        XCTAssertTrue(h.sentTo.isEmpty)
    }

    @MainActor
    func testImagePayloadUsesTheSameFocusAndPasteWorkflow() async {
        let h = PasteHarness()
        let image = ClipboardContent.image(Data([1, 2, 3, 4]))
        let result = await h.run(content: image)
        XCTAssertEqual(result, .pasted)
        XCTAssertEqual(h.copied, image)
        XCTAssertTrue(h.dismissed)
        XCTAssertEqual(h.sentTo, [h.target])
    }

    @MainActor
    func testDeniedImagePasteClosesAndRestoresTargetWithoutInjecting() async {
        let h = PasteHarness()
        h.trusted = false
        let image = ClipboardContent.image(Data([1, 2, 3, 4]))
        let result = await h.run(content: image)
        XCTAssertEqual(result, .accessibilityRequired)
        XCTAssertEqual(h.copied, image)
        XCTAssertTrue(h.dismissed)
        XCTAssertEqual(h.activationCount, 1)
        XCTAssertTrue(h.sentTo.isEmpty)
    }

    @MainActor
    func testImageSelectionClosesWithoutATargetButCopyFailureKeepsPanelOpen() async {
        let h = PasteHarness()
        let image = ClipboardContent.image(Data([1, 2, 3, 4]))
        let result = await h.run(target: nil, content: image)
        XCTAssertEqual(result, .noTarget)
        XCTAssertEqual(h.copied, image)
        XCTAssertTrue(h.dismissed)
        XCTAssertTrue(h.sentTo.isEmpty)

        let failed = PasteHarness()
        failed.shouldCopy = false
        let copyFailure = await failed.run(content: image)
        XCTAssertEqual(copyFailure, .clipboardWriteFailed)
        XCTAssertFalse(failed.dismissed)
    }

    @MainActor
    func testImageSelectionWaitsForReturnReleaseBeforeRestoringTheTarget() async {
        let h = PasteHarness()
        h.trusted = false
        h.keysReleased = false
        h.onWait = {
            XCTAssertFalse(h.dismissed)
            XCTAssertEqual(h.activationCount, 0)
            h.keysReleased = true
        }
        let result = await h.run(content: .image(Data([1, 2, 3, 4])))
        XCTAssertEqual(result, .accessibilityRequired)
        XCTAssertTrue(h.dismissed)
        XCTAssertTrue(h.sentTo.isEmpty)
    }

    @MainActor
    func testImagePasteFailuresStayClosedAndRemainAvailableOnNextOpening() async {
        for denied in [true, false] {
            let h = PasteHarness(target: ProcessInfo.processInfo.processIdentifier)
            h.trusted = !denied
            h.shouldSend = false
            let service = PasteService(coordinator: h.coordinator)
            var reopened = false
            let task = service.paste(.image(Data([1, 2, 3, 4])), into: .current,
                                     dismiss: { h.dismissed = true }, showFailure: { reopened = true })
            await task.value
            XCTAssertTrue(h.dismissed)
            XCTAssertFalse(reopened)
            XCTAssertEqual(service.lastFailure, denied ? .accessibilityRequired : .injectionFailed)
            service.prepareForPresentation()
            XCTAssertEqual(service.lastFailure, denied ? .accessibilityRequired : .injectionFailed)
            if denied {
                h.trusted = true
                service.prepareForPresentation()
                XCTAssertNil(service.lastFailure)
            }
        }
    }

    @MainActor
    func testTextPasteStillReopensThePanelAfterAnInjectionFailure() async {
        let h = PasteHarness(target: ProcessInfo.processInfo.processIdentifier)
        h.shouldSend = false
        let service = PasteService(coordinator: h.coordinator)
        var reopened = false
        await service.paste(.text("text"), into: .current,
                            dismiss: { h.dismissed = true }, showFailure: { reopened = true }).value
        XCTAssertTrue(h.dismissed)
        XCTAssertTrue(reopened)
        XCTAssertEqual(service.lastFailure, .injectionFailed)
    }

    @MainActor
    func testPasteEventsContainOnlyCommandVAndPairedKeyTransitions() throws {
        let events = try XCTUnwrap(PasteService.makePasteEvents())
        XCTAssertEqual(events.0.type, .keyDown)
        XCTAssertEqual(events.1.type, .keyUp)
        XCTAssertEqual(events.0.getIntegerValueField(.keyboardEventKeycode), Int64(kVK_ANSI_V))
        XCTAssertEqual(events.1.getIntegerValueField(.keyboardEventKeycode), Int64(kVK_ANSI_V))
        XCTAssertEqual(events.0.flags, .maskCommand)
        XCTAssertEqual(events.1.flags, .maskCommand)
    }
}
