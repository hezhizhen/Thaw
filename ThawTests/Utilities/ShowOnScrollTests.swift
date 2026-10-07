//
//  ShowOnScrollTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import CoreGraphics
import Testing
@testable import Thaw

@Suite("Show on scroll")
struct ShowOnScrollTests {
    @Test("Reverse scrolling still hides after revealed items fill the empty space")
    func hidesAfterRevealAreaBecomesOccupied() {
        #expect(HIDEventManager.scrollAction(averageDelta: 10, isInRevealArea: true) == .show)
        #expect(HIDEventManager.scrollAction(averageDelta: -10, isInRevealArea: false) == .hide)
    }

    @Test("Scrolling over an existing item does not reveal hidden items")
    func doesNotRevealOverExistingItem() {
        #expect(HIDEventManager.scrollAction(averageDelta: 10, isInRevealArea: false) == nil)
    }

    @Test("Empty space and the Thaw icon continue to support hiding")
    func hidesInRevealArea() {
        #expect(HIDEventManager.scrollAction(averageDelta: -10, isInRevealArea: true) == .hide)
    }

    @Test("Small gestures do not change visibility", arguments: [-5.0, -2.0, 0.0, 2.0, 5.0])
    func ignoresSmallGestures(delta: Double) {
        for isInRevealArea in [true, false] {
            #expect(HIDEventManager.scrollAction(averageDelta: CGFloat(delta), isInRevealArea: isInRevealArea) == nil)
        }
    }
}
