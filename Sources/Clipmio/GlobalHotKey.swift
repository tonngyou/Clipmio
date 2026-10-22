// Copyright (c) 2026 tonngyou. MIT License.
import Carbon.HIToolbox
import Observation

/// An application-event hotkey needs no Accessibility or Input Monitoring grant.
@Observable @MainActor
final class GlobalHotKey {
    private static var nextID: UInt32 = 0

    var onTrigger: (() -> Void)?
    private(set) var isRegistered = false
    private(set) var registrationError: OSStatus?

    @ObservationIgnored let eventID: EventHotKeyID
    private(set) var shortcut: KeyboardShortcut
    var shortcutLabel: String { shortcut.label }
    @ObservationIgnored private var hotKeyRef: EventHotKeyRef?
    @ObservationIgnored private var handlerRef: EventHandlerRef?

    init(shortcut: KeyboardShortcut = .default) {
        self.shortcut = shortcut.isValid ? shortcut : .default
        Self.nextID &+= 1
        eventID = EventHotKeyID(signature: 0x434D494F, id: Self.nextID) // CMIO
    }

    convenience init(keyCode: UInt32, modifiers: UInt32) {
        self.init(shortcut: KeyboardShortcut(keyCode: keyCode, modifiers: modifiers))
    }

    @discardableResult
    func start() -> Bool {
        if isRegistered { return true }
        return setShortcut(shortcut)
    }

    /// Try the replacement before releasing a working registration.
    @discardableResult
    func setShortcut(_ value: KeyboardShortcut) -> Bool {
        guard value.isValid else { return false }
        if isRegistered && value == shortcut { return true }
        if handlerRef == nil, !installHandler() { return false }
        var replacement: EventHotKeyRef?
        let status = RegisterEventHotKey(value.keyCode, value.modifiers, eventID,
                                        GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &replacement)
        guard status == noErr else {
            if !isRegistered { _ = fail(status) }
            return false
        }
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = replacement
        shortcut = value
        registrationError = nil
        isRegistered = true
        return true
    }

    private func installHandler() -> Bool {
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
