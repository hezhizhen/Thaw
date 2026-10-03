//
//  NativeVisibilityRecoveryLaunch.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import AppKit
import PlatformRuntimeKit

@MainActor
enum NativeVisibilityRecoveryLaunch {
    static let argument = "--recover-menu-bar-visibility"
    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains(argument)
    }

    private(set) static var isHandingOff = false

    static func conflictingApplications() -> [String] {
        var bundles: Set = ["com.stonerl.Thaw", "com.stonerl.Thaw.debug", "com.surteesstudios.Bartender"]
        if let currentBundle = Bundle.main.bundleIdentifier {
            bundles.insert(currentBundle)
        }
        return NSWorkspace.shared.runningApplications.compactMap { app in
            guard app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
                  !app.isTerminated, let bundle = app.bundleIdentifier, bundles.contains(bundle) else { return nil }
            return app.localizedName ?? bundle
        }
    }

    static func openRecovery() async throws {
        // The normal quit path may clear its journal using a cached read-back.
        // Keep a separate recovery intent until disk verification succeeds.
        try NativeAppVisibilityRecovery().preserveRecoveryRecords()
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.arguments = [argument]
        configuration.activates = true
        _ = try await NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration)
        isHandingOff = true
        ApplicationTermination.request()
    }
}

extension NativeVisibilityRecoveryModel {
    static func live() -> NativeVisibilityRecoveryModel {
        let ensureExclusive: @MainActor () throws -> Void = {
            guard NativeVisibilityRecoveryLaunch.isRequested else { throw RecoveryError.normalLaunch }
            guard NativeVisibilityRecoveryLaunch.conflictingApplications().isEmpty else { throw RecoveryError.otherManagerRunning }
        }
        let recovery = NativeAppVisibilityRecovery(ensureExclusiveAccess: ensureExclusive)
        let access = PickedFileAccess.controlCenterVisibilityRecovery
        return NativeVisibilityRecoveryModel(environment: Environment(
            conflictingApplications: NativeVisibilityRecoveryLaunch.conflictingApplications,
            disableNativeHiding: { Defaults.set(false, forKey: .enableNativeAppHiding) },
            requestAccess: { access.hasReadWriteAccess || (access.requestAccessViaOpenPanel() && access.hasReadWriteAccess) },
            inspect: {
                let inventory = try recovery.inspect()
                return (inventory.disabledBundleIDs, inventory.recordedBundleIDs)
            },
            restore: { try await recovery.restore(selectedBundleIDs: $0) },
            displayName: { bundleID in
                guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return bundleID }
                return url.deletingPathExtension().lastPathComponent
            }
        ))
    }
}
