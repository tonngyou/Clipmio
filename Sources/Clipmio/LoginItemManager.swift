// Copyright (c) 2026 tonngyou. MIT License.
import Foundation
import Observation
import ServiceManagement

enum LoginItemState {
    case disabled, enabled, requiresApproval, unavailable

    var isRequested: Bool { self == .enabled || self == .requiresApproval }
}

@MainActor
protocol LoginItemService {
    var state: LoginItemState { get }
    func register() throws
    func unregister() throws
    func openSettings()
}

@MainActor
private struct SystemLoginItemService: LoginItemService {
    var state: LoginItemState {
        switch SMAppService.mainApp.status {
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        case .notRegistered: .disabled
        case .notFound: .unavailable
        @unknown default: .unavailable
        }
    }

    func register() throws { try SMAppService.mainApp.register() }
    func unregister() throws { try SMAppService.mainApp.unregister() }
    func openSettings() { SMAppService.openSystemSettingsLoginItems() }
}

@MainActor @Observable
final class LoginItemManager {
    private let service: any LoginItemService
    let canManage: Bool
    private(set) var state: LoginItemState = .disabled
    private(set) var changeFailed = false

    init(service: (any LoginItemService)? = nil,
         canManage: Bool = Bundle.main.bundleURL.pathExtension == "app") {
        self.service = service ?? SystemLoginItemService()
        self.canManage = canManage
        refresh()
    }

    func refresh() {
        state = canManage ? service.state : .unavailable
    }

    func setEnabled(_ enabled: Bool) {
        guard canManage else { return }
        changeFailed = false
        refresh()
        do {
            if enabled && !state.isRequested { try service.register() }
            if !enabled && state.isRequested { try service.unregister() }
        } catch {
            changeFailed = true
        }
        // Never display a saved preference as though registration succeeded.
        refresh()
    }

    func openSettings() { if canManage { service.openSettings() } }
}
