import AppKit
import Carbon
import XCTest
@testable import Clipmio

final class LaunchPresentationTests: XCTestCase {
    @MainActor
    func testManualLaunchShowsHistoryAndRestartStaysInBackground() {
        XCTAssertTrue(LaunchPresentation.shouldOpenHistory(event: nil, arguments: []))
        XCTAssertTrue(LaunchPresentation.shouldOpenHistory(event: nil, arguments: ["--demo"]))
        XCTAssertFalse(LaunchPresentation.shouldOpenHistory(event: nil, arguments: ["--background"]))
    }

    @MainActor
    func testLoginAndServiceAppleEventsDoNotOpenHistory() {
        for reason in [keyAELaunchedAsLogInItem, keyAELaunchedAsServiceItem] {
            let event = NSAppleEventDescriptor.appleEvent(withEventClass: AEEventClass(kCoreEventClass),
                eventID: AEEventID(kAEOpenApplication), targetDescriptor: nil,
                returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
            event.setParam(NSAppleEventDescriptor(enumCode: OSType(reason)), forKeyword: AEKeyword(keyAEPropData))
            XCTAssertFalse(LaunchPresentation.shouldOpenHistory(event: event, arguments: []))
        }
        let manualEvent = NSAppleEventDescriptor.appleEvent(withEventClass: AEEventClass(kCoreEventClass),
            eventID: AEEventID(kAEOpenApplication), targetDescriptor: nil,
            returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
        XCTAssertTrue(LaunchPresentation.shouldOpenHistory(event: manualEvent, arguments: []))
    }
}
