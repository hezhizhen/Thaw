//
//  ThawBarHostingView.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import MenuBarModel
import SwiftUI

final class ThawBarHostingView: NSHostingView<ThawBarContentView> {
    override var safeAreaInsets: NSEdgeInsets {
        NSEdgeInsets()
    }

    override func layout() {
        super.layout()
        (window as? ThawBarPanel)?.resizeToContent()
    }

    init(
        appState: AppState,
        colorManager: ThawBarColorManager,
        keyboardFocus: ThawBarKeyboardFocus,
        screen: NSScreen,
        section: MenuBarSection.Name,
        showsOnlyThawBarOnlyItems: Bool,
        folderMembers: [String]?
    ) {
        super.init(
            rootView: Self.makeContentView(
                appState: appState,
                colorManager: colorManager,
                keyboardFocus: keyboardFocus,
                screen: screen,
                section: section,
                showsOnlyThawBarOnlyItems: showsOnlyThawBarOnlyItems,
                folderMembers: folderMembers
            )
        )
    }

    /// Reuse the hosting graph with new inputs; rebuilding on each show grows process-lifetime SwiftUI caches.
    func update(
        appState: AppState,
        colorManager: ThawBarColorManager,
        keyboardFocus: ThawBarKeyboardFocus,
        screen: NSScreen,
        section: MenuBarSection.Name,
        showsOnlyThawBarOnlyItems: Bool,
        folderMembers: [String]?
    ) {
        rootView = Self.makeContentView(
            appState: appState,
            colorManager: colorManager,
            keyboardFocus: keyboardFocus,
            screen: screen,
            section: section,
            showsOnlyThawBarOnlyItems: showsOnlyThawBarOnlyItems,
            folderMembers: folderMembers
        )
    }

    private static func makeContentView(
        appState: AppState,
        colorManager: ThawBarColorManager,
        keyboardFocus: ThawBarKeyboardFocus,
        screen: NSScreen,
        section: MenuBarSection.Name,
        showsOnlyThawBarOnlyItems: Bool,
        folderMembers: [String]?
    ) -> ThawBarContentView {
        ThawBarContentView(
            appState: appState,
            colorManager: colorManager,
            keyboardFocus: keyboardFocus,
            itemManager: appState.itemManager,
            imageCache: appState.imageCache,
            menuBarManager: appState.menuBarManager,
            visibleControlItem: appState.menuBarManager.section(withName: .visible)?.controlItem,
            screen: screen,
            section: section,
            showsOnlyThawBarOnlyItems: showsOnlyThawBarOnlyItems,
            folderMembers: folderMembers
        )
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @available(*, unavailable)
    required init(rootView _: ThawBarContentView) {
        fatalError("init(rootView:) has not been implemented")
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        return true
    }
}
