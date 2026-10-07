//
//  ShowOnScrollTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import CoreGraphics
import Testing
@testable import Thaw

/// Checks scroll direction and thresholds without live menu bar events.
@Suite("Show on scroll")
struct ShowOnScrollTests {
    /// Covers fractional and larger deltas above the reveal threshold.
    @Test("Scrolling past the show threshold reveals hidden items", arguments: [5.1, 10.0])
    func showsAboveThreshold(delta: Double) {
        #expect(HIDEventManager.scrollAction(averageDelta: CGFloat(delta)) == .show)
    }

    /// Covers fractional and larger deltas below the hide threshold.
    @Test("Reverse scrolling past the hide threshold hides items", arguments: [-5.1, -10.0])
    func hidesBelowThreshold(delta: Double) {
        #expect(HIDEventManager.scrollAction(averageDelta: CGFloat(delta)) == .hide)
    }

    /// Keeps threshold endpoints and smaller gestures from changing visibility.
    @Test("Small gestures do not change visibility", arguments: [-5.0, -2.0, 0.0, 2.0, 5.0])
    func ignoresSmallGestures(delta: Double) {
        #expect(HIDEventManager.scrollAction(averageDelta: CGFloat(delta)) == nil)
    }
}
