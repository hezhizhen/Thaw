//
//  ThawBarBackgroundSampleTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import AppKit
import SwiftUI
import Testing
@testable import Thaw

@MainActor
@Suite("Thaw Bar background sampling")
struct ThawBarBackgroundSampleTests {
    @Test("Inherited appearance uses the full display sample, not the gray right-edge crop")
    func inheritedAppearanceMatchesMenuBar() throws {
        let context = try #require(CGContext(
            data: nil, width: 1920, height: 1, bitsPerComponent: 8, bytesPerRow: 1920 * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(srgbRed: 0.29, green: 0.45, blue: 0.63, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 1620, height: 1))
        context.setFillColor(CGColor(srgbRed: 0.76, green: 0.78, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 1620, y: 0, width: 300, height: 1))
        let strip = try #require(context.makeImage())
        let edge = try #require(strip.cropping(to: CGRect(x: 1770, y: 0, width: 150, height: 1)))
        let blue = try MenuBarAverageColorInfo(color: #require(strip.averageColor(option: .ignoreAlpha)), source: .menuBarWindow)
        let gray = try MenuBarAverageColorInfo(color: #require(edge.averageColor()), source: .menuBarWindow)
        let configuration = MenuBarAppearanceConfigurationV2.defaultConfiguration
        #expect(!configuration.thawBarAppearance.overridesMenuBar)
        let sample = try #require(ThawBarColorManager.backgroundSample(
            for: 1,
            overridesMenuBar: configuration.thawBarAppearance.overridesMenuBar,
            sharedSamples: [1: blue],
            localSample: gray
        ))
        #expect(sample == blue)
        let ink = ThawBarAppearanceForeground.resolve(
            appearance: configuration.resolvedThawBarAppearance,
            sampledInfo: sample,
            adaptiveInfo: blue,
            palette: nil,
            screen: nil
        )
        #expect(ink == .white)
    }

    @Test("The inherited sample belongs to the requested display, or remains unavailable")
    func displayIsolationAndColdStart() {
        let dark = MenuBarAverageColorInfo(color: NSColor.black.cgColor, source: .menuBarWindow)
        let light = MenuBarAverageColorInfo(color: NSColor.white.cgColor, source: .menuBarWindow)
        var samples: [CGDirectDisplayID: MenuBarAverageColorInfo] = [1: dark]
        #expect(ThawBarColorManager.backgroundSample(
            for: 2, overridesMenuBar: false, sharedSamples: samples, localSample: dark
        ) == nil)
        samples[2] = light
        #expect(ThawBarColorManager.backgroundSample(
            for: 2, overridesMenuBar: false, sharedSamples: samples, localSample: dark
        ) == light)
        #expect(ThawBarColorManager.backgroundSample(
            for: 1, overridesMenuBar: false, sharedSamples: samples, localSample: light
        ) == dark)
    }

    @Test("Switching own look on and off changes the sample without overwriting either source")
    func ownLookRetainsLocalSample() {
        let shared = MenuBarAverageColorInfo(color: NSColor.blue.cgColor, source: .menuBarWindow)
        let local = MenuBarAverageColorInfo(color: NSColor.gray.cgColor, source: .menuBarWindow)
        for overrides in [false, true, false] {
            #expect(ThawBarColorManager.backgroundSample(
                for: 1, overridesMenuBar: overrides, sharedSamples: [1: shared], localSample: local
            ) == (overrides ? local : shared))
        }
        #expect(ThawBarColorManager.backgroundSample(
            for: 1, overridesMenuBar: true, sharedSamples: [1: shared], localSample: nil
        ) == nil)
    }

    @Test("Foreground contrast still follows an opaque custom background", arguments: [false, true])
    func customBackgroundContrast(isLight: Bool) {
        var configuration = MenuBarAppearanceConfigurationV2.defaultConfiguration
        configuration.thawBarAppearance.overridesMenuBar = true
        configuration.thawBarAppearance.backgroundKind = .solid
        configuration.thawBarAppearance.backgroundColor = isLight ? NSColor.white.cgColor : NSColor.black.cgColor
        configuration.thawBarAppearance.backgroundOpacity = 1
        configuration.thawBarAppearance.tintKind = .noTint
        let sample = MenuBarAverageColorInfo(color: NSColor.gray.cgColor, source: .menuBarWindow)
        let ink = ThawBarAppearanceForeground.resolve(
            appearance: configuration.resolvedThawBarAppearance,
            sampledInfo: sample, adaptiveInfo: nil, palette: nil, screen: nil
        )
        #expect(ink == (isLight ? Color.black : Color.white))
    }
}
