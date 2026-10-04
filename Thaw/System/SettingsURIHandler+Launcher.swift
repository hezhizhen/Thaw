//
//  SettingsURIHandler+Launcher.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import Foundation
import MenuBarModel

// MARK: - Launcher Operations

extension SettingsURIHandler {
    /// Handles the four launcher operations; the caller has already passed the whitelist gate.
    /// Lists need a response mechanism. The two actions run without one, as other thaw:// actions do.
    static func handleLauncherRequest(
        _ request: LauncherURIRequest,
        sender: String?,
        appState: AppState
    ) async {
        let requestId = request.requestId ?? UUID().uuidString
        let operation = request.operation
        diagLog.debug("Launcher URI: \(operation.rawValue) from \(sender ?? "unknown")")

        let response: [String: Any]
        switch operation {
        case .listItems, .listProfiles, .getAppearance:
            guard request.hasResponseMechanism else {
                diagLog.warning("Launcher URI \(operation.rawValue): provide callback=<url> or broadcast=true")
                return
            }
            response = queryResponse(for: operation, appState: appState, requestId: requestId)
        case .activateItem, .applyProfile:
            if let identifier = request.identifier {
                response = operation == .activateItem
                    ? await activateItemResponse(identifier: identifier, appState: appState, requestId: requestId)
                    : await applyProfileResponse(identifier: identifier, appState: appState, requestId: requestId)
            } else {
                let parameter = operation.identifierParameter ?? "identifier"
                diagLog.warning("Launcher URI \(operation.rawValue): missing \(parameter)")
                response = LauncherURIResponse.failure(
                    LauncherURIResponse.invalidRequest,
                    details: "Provide \(parameter)=<id>",
                    operation: operation,
                    requestId: requestId
                )
            }
        }

        deliverLauncherResponse(response, for: request, requestId: requestId)
    }

    /// The answer to an operation that only reads state.
    private static func queryResponse(
        for operation: LauncherURIOperation,
        appState: AppState,
        requestId: String
    ) -> [String: Any] {
        switch operation {
        case .listItems:
            listItemsResponse(appState: appState, requestId: requestId)
        case .getAppearance:
            appearanceResponse(appState: appState, requestId: requestId)
        case .listProfiles, .activateItem, .applyProfile:
            listProfilesResponse(appState: appState, requestId: requestId)
        }
    }

    private static func listItemsResponse(appState: AppState, requestId: String) -> [String: Any] {
        // An empty list would read as an empty menu bar, so say why instead.
        guard appState.permissions.accessibility.hasPermission else {
            return LauncherURIResponse.failure(
                LauncherURIResponse.permissionMissing,
                details: "Accessibility permission is not granted",
                operation: .listItems,
                requestId: requestId
            )
        }

        let controller = appState.menuBarManager.sectionController
        // The same filter the Shortcuts item picker uses, so every listed
        // identifier is one activate-item resolves.
        let items = appState.itemManager.managedItems
            .filter(\.isUserActionable)
            .map { item in
                LauncherURIPayload.Item(
                    id: item.uniqueIdentifier,
                    name: MenuBarItemDisplayName.displayName(for: item),
                    section: controller.section(for: item).rawValue,
                    bundleId: (item.sourceApplication ?? item.owningApplication)?.bundleIdentifier
                )
            }
        return LauncherURIResponse.success(
            LauncherURIPayload.ItemList(items: items),
            operation: .listItems,
            requestId: requestId
        )
    }

    private static func appearanceResponse(appState: AppState, requestId: String) -> [String: Any] {
        let configuration = appState.appearanceManager.effectiveConfiguration
        return LauncherURIResponse.success(
            SharedAppearance(
                configuration: configuration.current,
                shapeKind: configuration.shapeKind,
                hasRoundedShape: configuration.hasRoundedShape,
                isDark: SystemAppearance.current == .dark
            ),
            operation: .getAppearance,
            requestId: requestId
        )
    }

    private static func listProfilesResponse(appState: AppState, requestId: String) -> [String: Any] {
        LauncherURIResponse.success(
            LauncherURIPayload.ProfileList(
                profiles: appState.profileManager.profiles,
                activeProfileID: appState.profileManager.activeProfileID
            ),
            operation: .listProfiles,
            requestId: requestId
        )
    }

    private static func activateItemResponse(
        identifier: String,
        appState: AppState,
        requestId: String
    ) async -> [String: Any] {
        let outcome = await appState.itemManager.activateItem(withIdentifier: identifier)
        diagLog.info("Launcher URI activate-item: \(identifier) -> \(outcome)")
        return LauncherURIResponse.activation(itemId: identifier, outcome: outcome, requestId: requestId)
    }

    private static func applyProfileResponse(
        identifier: String,
        appState: AppState,
        requestId: String
    ) async -> [String: Any] {
        let manager = appState.profileManager
        let outcome: LauncherProfileApplyOutcome
        if let profileID = UUID(uuidString: identifier), manager.profiles.contains(where: { $0.id == profileID }) {
            do {
                try await manager.applyProfileAwaitingLayout(id: profileID, to: appState)
                outcome = manager.layoutDidNotRun ? .appliedWithoutLayout : .applied
            } catch {
                diagLog.error("Launcher URI apply-profile: \(identifier) failed to load: \(error)")
                outcome = .applyFailed
            }
        } else {
            outcome = .profileUnavailable
        }
        diagLog.info("Launcher URI apply-profile: \(identifier) -> \(outcome.rawValue)")
        return LauncherURIResponse.profileApplication(profileId: identifier, outcome: outcome, requestId: requestId)
    }

    /// Same split as thaw://get: the full response goes only to the callback;
    /// a broadcast, which any process can hear, gets an acknowledgement.
    private static func deliverLauncherResponse(
        _ response: [String: Any],
        for request: LauncherURIRequest,
        requestId: String
    ) {
        if let callback = request.callback {
            _ = sendCallbackResponse(response: response, callback: callback)
        } else if request.broadcast {
            _ = sendBroadcastResponse(response: [
                "requestId": requestId,
                "operation": request.operation.rawValue,
                "status": "ack",
                "message": "Use callback URL to receive the full response",
            ])
        }
    }
}
