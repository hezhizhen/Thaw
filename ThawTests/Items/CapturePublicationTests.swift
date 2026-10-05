//
//  CapturePublicationTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import CoreGraphics
import MenuBarModel
import Testing
@testable import Thaw

@Suite("Capture publication")
struct CapturePublicationTests {
    private typealias Policy = CapturePublicationPolicy
    private let display: CGDirectDisplayID = 42

    private func rejection(
        _ admission: CapturePublicationAdmission,
        layout: MenuBarLayoutPublicationState,
        displayID: CGDirectDisplayID? = 42,
        isResettingLayout: Bool = false,
        moveWithinCooldown: Bool = false,
        ignoreRecentMove: Bool = false
    ) -> Policy.Rejection? {
        Policy.rejection(
            of: admission,
            layout: layout,
            displayID: displayID,
            isResettingLayout: isResettingLayout,
            moveWithinCooldown: moveWithinCooldown,
            ignoreRecentMove: ignoreRecentMove
        )
    }

    @Test("A capture on a quiet layout and the same display publishes", arguments: [false, true])
    func quietCaptureIsPublished(forced: Bool) {
        var layout = MenuBarLayoutPublicationState()
        layout.invalidate()
        let admission = Policy.admit(layout: layout, displayID: display)

        #expect(rejection(admission, layout: layout, ignoreRecentMove: forced) == nil)
    }

    @Test("A move that completed after admission rejects the capture", arguments: [false, true])
    func completedMoveRejects(forced: Bool) {
        var layout = MenuBarLayoutPublicationState()
        let admission = Policy.admit(layout: layout, displayID: display)
        layout.beginMutation()
        layout.endMutation()

        #expect(rejection(admission, layout: layout, ignoreRecentMove: forced) == .layoutChanged)
    }

    @Test("A mutation still running at publication rejects the capture")
    func activeMutationRejects() {
        var layout = MenuBarLayoutPublicationState()
        let admission = Policy.admit(layout: layout, displayID: display)
        layout.beginMutation()

        #expect(rejection(admission, layout: layout, ignoreRecentMove: true) == .layoutChanged)
    }

    @Test("A capture admitted inside a mutation never publishes, even after it ends")
    func admissionInsideMutationNeverPublishes() {
        var layout = MenuBarLayoutPublicationState()
        layout.beginMutation()
        let admission = Policy.admit(layout: layout, displayID: display)
        #expect(rejection(admission, layout: layout) == .layoutChanged)
        layout.endMutation()
        #expect(rejection(admission, layout: layout) == .layoutChanged)
    }

    @Test("An authored layout invalidation rejects the capture")
    func invalidationRejects() {
        var layout = MenuBarLayoutPublicationState()
        let admission = Policy.admit(layout: layout, displayID: display)
        layout.invalidate()

        #expect(rejection(admission, layout: layout) == .layoutChanged)
    }

    @Test("A display switch rejects an otherwise current capture", arguments: [CGDirectDisplayID(7), nil])
    func displaySwitchRejects(current: CGDirectDisplayID?) {
        let layout = MenuBarLayoutPublicationState()
        let admission = Policy.admit(layout: layout, displayID: display)

        #expect(rejection(admission, layout: layout, displayID: current) == .displayChanged)
    }

    @Test("A forced post-reorder refresh ignores the cooldown of the move that already completed")
    func forcedRefreshAfterCompletedMovePublishes() {
        var layout = MenuBarLayoutPublicationState()
        layout.beginMutation()
        layout.endMutation()
        let admission = Policy.admit(layout: layout, displayID: display)

        #expect(rejection(admission, layout: layout, moveWithinCooldown: true) == .recentMove)
        #expect(rejection(admission, layout: layout, moveWithinCooldown: true, ignoreRecentMove: true) == nil)
    }

    @Test("A forced refresh cannot outrun a move that starts during it", arguments: [false, true])
    func newMutationDuringForcedRefreshRejects(finishesBeforePublication: Bool) {
        var layout = MenuBarLayoutPublicationState()
        layout.beginMutation()
        layout.endMutation()
        let admission = Policy.admit(layout: layout, displayID: display)
        layout.beginMutation()
        if finishesBeforePublication {
            layout.endMutation()
        }

        #expect(rejection(
            admission, layout: layout, moveWithinCooldown: true, ignoreRecentMove: true
        ) == .layoutChanged)
    }

    @Test("A layout reset in progress rejects even a forced refresh")
    func layoutResetRejectsForcedRefresh() {
        let layout = MenuBarLayoutPublicationState()
        let admission = Policy.admit(layout: layout, displayID: display)

        #expect(rejection(admission, layout: layout, isResettingLayout: true, ignoreRecentMove: true) == .layoutResetting)
    }

    @Test("The admitted generation is a snapshot, not a view of the live state")
    func admissionIsASnapshot() {
        var layout = MenuBarLayoutPublicationState()
        let admission = Policy.admit(layout: layout, displayID: display)
        layout.invalidate()

        #expect(admission.layoutGeneration != layout.generation)
        #expect(rejection(Policy.admit(layout: layout, displayID: display), layout: layout) == nil)
    }
}

@MainActor
@Suite("Capture failure ledger commit")
struct CaptureLedgerCommitTests {
    private func makeItem(title: String) -> MenuBarItem {
        MenuBarItem(
            tag: MenuBarItemTag(namespace: .string("com.example.ledger"), title: title, instanceIndex: 0),
            windowID: 301,
            ownerPID: 999_993,
            sourcePID: 999_993,
            bounds: CGRect(x: 1000, y: 4.5, width: 24, height: 24),
            title: title,
            isOnScreen: true
        )
    }

    private func strikes(for item: MenuBarItem, in cache: MenuBarItemImageCache) -> Int {
        cache.failedCapturesLock.withLock { $0[item.tag]?.failureCount ?? 0 }
    }

    @Test("Strikes and recoveries wait for the pass to be committed")
    func ledgerChangesOnlyOnCommit() {
        let cache = MenuBarItemImageCache(screenIsLocked: { false })
        let struck = makeItem(title: "Struck")
        let forgiven = makeItem(title: "Forgiven")
        cache.recordCaptureFailure(for: forgiven)

        var pass = MenuBarItemImageCache.CapturePass()
        pass.failedCaptureItems = [struck]
        pass.recoveredItems = [forgiven]

        #expect(strikes(for: struck, in: cache) == 0)
        #expect(strikes(for: forgiven, in: cache) == 1)
        cache.commitCaptureLedger(of: pass)
        #expect(strikes(for: struck, in: cache) == 1)
        #expect(strikes(for: forgiven, in: cache) == 0)
    }
}
