//
//  OverflowOrderPersistenceTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import Foundation
import MenuBarModel
import Testing
@testable import Thaw

/// Automatic overflow is presentation, not a layout edit. A profile or saved
/// order captured while the bar was tight must keep an authored-Visible item
/// in its Visible slot instead of recording it as Hidden.
@MainActor
@Suite("Overflow order persistence")
struct OverflowOrderPersistenceTests {
    private static func item(_ title: String, x: CGFloat) -> MenuBarItem {
        MenuBarItem(
            tag: MenuBarItemTag(namespace: .string("com.example.\(title)"), title: title, instanceIndex: 0),
            windowID: UInt32(x) + 1,
            ownerPID: 100,
            sourcePID: 200,
            bounds: CGRect(x: x, y: 0, width: 24, height: 24),
            title: title,
            isOnScreen: true
        )
    }

    private static func transientItem(_ title: String, x: CGFloat) -> MenuBarItem {
        MenuBarItem(
            tag: MenuBarItemTag(namespace: .menuBarAgent, title: title, instanceIndex: 0),
            windowID: UInt32(x) + 1,
            ownerPID: 100,
            sourcePID: 200,
            bounds: CGRect(x: x, y: 0, width: 24, height: 24),
            title: title,
            isOnScreen: true
        )
    }

    private static func visibleProjection(
        order: [String],
        assignment: [String: MenuBarSectionName] = [:]
    ) -> MenuBarItemManager.AuthoredLayoutProjection {
        MenuBarItemManager.AuthoredLayoutProjection(
            sectionAssignment: assignment,
            sectionOrder: [.visible: order]
        )
    }

    @Test("An overflowed Visible item keeps its Visible slot in the persisted order")
    func overflowedVisibleItemKeepsItsSlot() {
        let a = Self.item("A", x: 10)
        let b = Self.item("B", x: 40)
        let c = Self.item("C", x: 70)
        let manager = MenuBarItemManager()
        manager.itemCache[.visible] = [a, c]
        manager.itemCache[.hidden] = [b]
        manager.savedSectionOrder = [MenuBarSectionName.visible.rawValue: [a, b, c].map(\.uniqueIdentifier)]

        let order = manager.computeSectionOrder(
            from: manager.itemCache,
            projection: Self.visibleProjection(order: [a, b, c].map(\.uniqueIdentifier))
        )

        #expect(order[MenuBarSectionName.visible.rawValue] == [a, b, c].map(\.uniqueIdentifier))
        #expect(order[MenuBarSectionName.hidden.rawValue] == nil)
    }

    @Test("Multiple overflowed Visible items reinsert at their recorded slots")
    func multipleOverflowedItemsKeepTheirSlots() {
        let a = Self.item("A", x: 10)
        let b = Self.item("B", x: 40)
        let c = Self.item("C", x: 70)
        let d = Self.item("D", x: 100)
        let e = Self.item("E", x: 130)
        let manager = MenuBarItemManager()
        manager.itemCache[.visible] = [a, c, e]
        manager.itemCache[.hidden] = [b, d]

        let order = manager.computeSectionOrder(
            from: manager.itemCache,
            projection: Self.visibleProjection(order: [a, b, c, d, e].map(\.uniqueIdentifier))
        )

        #expect(order[MenuBarSectionName.visible.rawValue] == [a, b, c, d, e].map(\.uniqueIdentifier))
    }

    @Test("A truly authored-Hidden item stays Hidden")
    func authoredHiddenItemStaysHidden() {
        let a = Self.item("A", x: 10)
        let b = Self.item("B", x: 40)
        let c = Self.item("C", x: 70)
        let manager = MenuBarItemManager()
        manager.itemCache[.visible] = [a, c]
        manager.itemCache[.hidden] = [b]

        let projection = MenuBarItemManager.AuthoredLayoutProjection(
            sectionAssignment: [b.uniqueIdentifier: .hidden],
            sectionOrder: [.visible: [a, c].map(\.uniqueIdentifier), .hidden: [b.uniqueIdentifier]]
        )
        let order = manager.computeSectionOrder(from: manager.itemCache, projection: projection)

        #expect(order[MenuBarSectionName.visible.rawValue] == [a, c].map(\.uniqueIdentifier))
        #expect(order[MenuBarSectionName.hidden.rawValue] == [b.uniqueIdentifier])
    }

    @Test("An explicitly hidden former overflow item persists Hidden")
    func explicitlyHiddenFormerOverflowPersistsHidden() {
        let a = Self.item("A", x: 10)
        let b = Self.item("B", x: 40)
        let c = Self.item("C", x: 70)
        let manager = MenuBarItemManager()
        manager.itemCache[.visible] = [a, c]
        manager.itemCache[.hidden] = [b]
        manager.savedSectionOrder = [MenuBarSectionName.visible.rawValue: [a, b, c].map(\.uniqueIdentifier)]

        let projection = MenuBarItemManager.AuthoredLayoutProjection(
            sectionAssignment: [b.uniqueIdentifier: .hidden],
            sectionOrder: [.visible: [a, c].map(\.uniqueIdentifier), .hidden: [b.uniqueIdentifier]]
        )
        let order = manager.computeSectionOrder(from: manager.itemCache, projection: projection)

        #expect(order[MenuBarSectionName.visible.rawValue] == [a, c].map(\.uniqueIdentifier))
        #expect(order[MenuBarSectionName.hidden.rawValue] == [b.uniqueIdentifier])
    }

    @Test("A closed app keeps its slot while a Visible item is overflowed")
    func closedAppSlotSurvivesAlongsideOverflow() {
        let a = Self.item("A", x: 10)
        let b = Self.item("B", x: 40)
        let c = Self.item("C", x: 70)
        let closed = Self.item("Closed", x: 0).uniqueIdentifier
        let manager = MenuBarItemManager()
        manager.itemCache[.visible] = [a, c]
        manager.itemCache[.hidden] = [b]
        manager.savedSectionOrder = [
            MenuBarSectionName.visible.rawValue: [a.uniqueIdentifier, b.uniqueIdentifier, closed, c.uniqueIdentifier],
        ]

        let order = manager.computeSectionOrder(
            from: manager.itemCache,
            projection: Self.visibleProjection(
                order: [a.uniqueIdentifier, b.uniqueIdentifier, closed, c.uniqueIdentifier]
            )
        )

        #expect(order[MenuBarSectionName.visible.rawValue] == [a.uniqueIdentifier, b.uniqueIdentifier, closed, c.uniqueIdentifier])
    }

    @Test("Transient Control Center widgets stay out of the projected order")
    func transientWidgetsStayExcluded() {
        let a = Self.item("A", x: 10)
        let transient = Self.transientItem("Item-0", x: 40)
        let manager = MenuBarItemManager()
        manager.itemCache[.visible] = [a, transient]

        let order = manager.computeSectionOrder(
            from: manager.itemCache,
            projection: Self.visibleProjection(order: [a.uniqueIdentifier, transient.uniqueIdentifier])
        )

        #expect(order[MenuBarSectionName.visible.rawValue] == [a.uniqueIdentifier])
    }

    @Test("Clearing overflow restores presentation without changing saved layout")
    func clearingOverflowLeavesSavedLayoutUnchanged() {
        let a = Self.item("A", x: 10)
        let b = Self.item("B", x: 40)
        let c = Self.item("C", x: 70)
        let manager = MenuBarItemManager()
        manager.itemCache[.visible] = [a, b, c]

        let order = manager.computeSectionOrder(
            from: manager.itemCache,
            projection: Self.visibleProjection(order: [a, b, c].map(\.uniqueIdentifier))
        )

        #expect(order[MenuBarSectionName.visible.rawValue] == [a, b, c].map(\.uniqueIdentifier))
    }

    @Test("Repeated capture is idempotent and leaves the presentation cache untouched")
    func repeatedCaptureIsIdempotent() {
        let a = Self.item("A", x: 10)
        let b = Self.item("B", x: 40)
        let c = Self.item("C", x: 70)
        let manager = MenuBarItemManager()
        manager.itemCache[.visible] = [a, c]
        manager.itemCache[.hidden] = [b]
        let before = manager.itemCache
        let projection = Self.visibleProjection(order: [a, b, c].map(\.uniqueIdentifier))

        let first = manager.computeSectionOrder(from: manager.itemCache, projection: projection)
        let second = manager.computeSectionOrder(from: manager.itemCache, projection: projection)

        #expect(first == second)
        #expect(manager.itemCache == before)
    }

    @Test("No projection keeps the effective cache as authority")
    func noProjectionKeepsLegacySemantics() {
        let a = Self.item("A", x: 10)
        let b = Self.item("B", x: 40)
        let c = Self.item("C", x: 70)
        let manager = MenuBarItemManager()
        manager.itemCache[.visible] = [a, c]
        manager.itemCache[.hidden] = [b]

        let order = manager.computeSectionOrder(from: manager.itemCache, projection: nil)

        #expect(order[MenuBarSectionName.visible.rawValue] == [a, c].map(\.uniqueIdentifier))
        #expect(order[MenuBarSectionName.hidden.rawValue] == [b.uniqueIdentifier])
    }
}
