import XCTest

/// Launches the app on canned data, in English, so every screen state can be reached without a network.
@MainActor
func launchApp(catalog: String = "loaded", favorites: String = "none") -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments += [
        "-catalog-stub", catalog,
        "-favorites", favorites,
        "-AppleLanguages", "(en)",
        "-AppleLocale", "en_GB"
    ]
    app.launch()
    return app
}

/// How long to wait for something the stub produces at once, with room for a slow simulator.
let shortWait: TimeInterval = 10

extension XCUIApplication {
    var discoverTab: XCUIElement { tabBars.buttons["Discover"] }
    var favouritesTab: XCUIElement { tabBars.buttons["Favourites"] }

    var searchField: XCUIElement { textFields["Search videos"] }

    /// The heart for one video, saved or not.
    func heart(for title: String, saved: Bool) -> XCUIElement {
        let label = saved ? "Remove from favourites" : "Save to favourites"
        return buttons.matching(NSPredicate(format: "label == %@ AND value == %@", label, title)).firstMatch
    }

    func text(_ label: String) -> XCUIElement {
        staticTexts[label]
    }

    /// Scrolls the frontmost scroll view until `element` exists, at most `swipes` times.
    func scroll(to element: XCUIElement, swipes: Int = 8) {
        for _ in 0..<swipes where !element.exists {
            swipeUp()
        }
    }
}

extension XCUIElement {
    /// Waits until the element is gone.
    func waitForDisappearance(timeout: TimeInterval = shortWait) -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: self)
        return XCTWaiter().wait(for: [gone], timeout: timeout) == .completed
    }
}
