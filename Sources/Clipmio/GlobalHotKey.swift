// Copyright (c) 2026 tonngyou. MIT License.
import Carbon.HIToolbox
import Observation

/// An application-event hotkey needs no Accessibility or Input Monitoring grant.
@Observable @MainActor
final class GlobalHotKey {
    static let shortcutLabel = "⌘⇧V"
    private static var nextID: UInt32 = 0

    var onTrigger: (() -> Void)?
    private(set) var isRegistered = false
    private(set) var registrationError: OSStatus?

    @ObservationIgnored let eventID: EventHotKeyID
    @ObservationIgnored private let keyCode: UInt32
    @ObservationIgnored private let modifiers: UInt32
    @ObservationIgnored private var hotKeyRef: EventHotKeyRef?
    @ObservationIgnored private var handlerRef: EventHandlerRef?

    init(keyCode: UInt32 = UInt32(kVK_ANSI_V), modifiers: UInt32 = UInt32(cmdKey | shiftKey)) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        Self.nextID &+= 1
        eventID = EventHotKeyID(signature: 0x434D494F, id: Self.nextID) // CMIO
    }

    @discardableResult
    func start() -> Bool {
        guard !isRegistered else { return true }
        stop()
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                  eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        let handlerStatus = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var identifier = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID), nil,
                                           MemoryLayout<EventHotKeyID>.size, nil, &identifier)
            guard status == noErr else { return status }
            let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(context).takeUnretainedValue()
            // AppKit dispatches the application event target on its main event loop.
            return MainActor.assumeIsolated {
                guard hotKey.isRegistered,
                      identifier.signature == hotKey.eventID.signature,
                      identifier.id == hotKey.eventID.id else { return OSStatus(eventNotHandledErr) }
                hotKey.onTrigger?()
                return noErr
            }
        }, 1, &event, context, &handlerRef)
        guard handlerStatus == noErr else { return fail(handlerStatus) }

        let status = RegisterEventHotKey(keyCode, modifiers, eventID,
                                         GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &hotKeyRef)
        guard status == noErr else { return fail(status) }
        registrationError = nil
        isRegistered = true
        return true
    }

    /// Must be called before the owner releases this object (also on application exit).
    func stop() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
        hotKeyRef = nil
        handlerRef = nil
        isRegistered = false
        registrationError = nil
    }

    private func fail(_ status: OSStatus) -> Bool {
        stop()
        registrationError = status
        return false
    }
}
