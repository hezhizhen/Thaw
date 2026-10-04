//
//  LeadingEdgePollIntervalTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import Testing
@testable import Thaw

@Suite("Leading edge poll interval")
struct LeadingEdgePollIntervalTests {
    private let now = ContinuousClock.now

    @Test("An idle bar is polled at the idle interval")
    func idleWithoutAWindow() {
        let interval = MenuBarLeadingEdgeWatcher.pollInterval(now: now, fastUntil: nil)
        #expect(interval == MenuBarLeadingEdgeWatcher.pollInterval)
    }

    @Test("Inside the window after a change the bar is polled fast")
    func fastInsideTheWindow() {
        let interval = MenuBarLeadingEdgeWatcher.pollInterval(now: now, fastUntil: now + .seconds(1))
        #expect(interval == MenuBarLeadingEdgeWatcher.fastPollInterval)
    }

    @Test("Once the window has passed polling returns to idle")
    func idleAfterTheWindow() {
        let interval = MenuBarLeadingEdgeWatcher.pollInterval(now: now, fastUntil: now - .milliseconds(1))
        #expect(interval == MenuBarLeadingEdgeWatcher.pollInterval)
    }
}
