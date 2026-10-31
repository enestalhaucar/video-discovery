import XCTest

/// The Discover tab: paging, search and the loading, error and empty states.
@MainActor
final class DiscoverUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testFeedShowsThreeCardsThenRevealsMoreWhileScrolling() {
        let app = launchApp()

        XCTAssertTrue(app.text("Big Buck Bunny").waitForExistence(timeout: shortWait))
        XCTAssertTrue(app.text("City Road").exists)
        XCTAssertTrue(app.text("Buses by the Park").exists)
        XCTAssertFalse(app.text("Passing Traffic").exists, "Only the first batch of three is revealed at launch")

        // The second batch arrives when the footer scrolls into view, and stops at six.
        app.scroll(to: app.text("Around the Park"))
        XCTAssertTrue(app.text("Around the Park").waitForExistence(timeout: shortWait))
        XCTAssertFalse(app.text("Unavailable Preview").exists, "The third batch waits for the next scroll")

        // The last batch holds the remaining two, then the list ends.
        app.scroll(to: app.text("You’re all caught up"))
        XCTAssertTrue(app.text("Unavailable Preview").exists)
        XCTAssertTrue(app.text("City Road: Another Look").exists)
        XCTAssertTrue(app.text("You’re all caught up").exists)
        XCTAssertFalse(app.text("Loading more…").exists)
    }

    func testSearchFiltersTheWholeCatalogue() {
        let app = launchApp()
        XCTAssertTrue(app.text("Big Buck Bunny").waitForExistence(timeout: shortWait))

        app.searchField.tap()
        app.searchField.typeText("park")
        XCTAssertTrue(app.text("Buses by the Park").waitForExistence(timeout: shortWait))
        XCTAssertTrue(app.text("Around the Park").exists, "Search reaches videos that weren't revealed yet")
        XCTAssertTrue(app.text("Big Buck Bunny").waitForDisappearance())
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label == 'Save to favourites'")).count, 2)

        app.buttons["Clear search"].tap()
        app.searchField.tap()
        app.searchField.typeText("unavailable")
        XCTAssertTrue(app.text("Unavailable Preview").waitForExistence(timeout: shortWait))
        XCTAssertTrue(app.text("Buses by the Park").waitForDisappearance())

        app.buttons["Clear search"].tap()
        app.searchField.tap()
        app.searchField.typeText("ocean")
        XCTAssertTrue(app.text("No results for “ocean”").waitForExistence(timeout: shortWait))
        XCTAssertTrue(app.text("Try a different title.").exists)
        XCTAssertFalse(app.text("Unavailable Preview").exists)
    }

    func testErrorOffersTryAgain() {
        let app = launchApp(catalog: "error")

        XCTAssertTrue(app.text("Couldn’t load videos").waitForExistence(timeout: shortWait))
        XCTAssertTrue(app.text("Check your connection and try again.").exists)
        let tryAgain = app.buttons["Try again"]
        XCTAssertTrue(tryAgain.exists)

        // The stub keeps failing, so the error comes back with the button usable again.
        tryAgain.tap()
        XCTAssertTrue(app.text("Couldn’t load videos").waitForExistence(timeout: shortWait))
        XCTAssertTrue(tryAgain.waitForExistence(timeout: shortWait))
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: tryAgain)
        XCTAssertEqual(XCTWaiter().wait(for: [enabled], timeout: shortWait), .completed)
        XCTAssertFalse(app.text("Big Buck Bunny").exists)
    }

    func testEmptyCatalogue() {
        let app = launchApp(catalog: "empty")

        XCTAssertTrue(app.text("No videos yet").waitForExistence(timeout: shortWait))
        XCTAssertTrue(app.text("New videos will show up here.").exists)
        XCTAssertFalse(app.buttons["Try again"].exists)
    }

    func testSkeletonShowsWhileTheCatalogueLoads() {
        let app = launchApp(catalog: "slow")

        // The slow stub answers after four seconds; until then three placeholder cards stand in.
        let skeletons = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Loading'"))
        XCTAssertTrue(skeletons.firstMatch.waitForExistence(timeout: shortWait))
        XCTAssertEqual(skeletons.count, 3)
        XCTAssertFalse(app.text("Big Buck Bunny").exists)

        XCTAssertTrue(app.text("Big Buck Bunny").waitForExistence(timeout: shortWait))
        XCTAssertTrue(skeletons.firstMatch.waitForDisappearance())
    }

    func testOpeningACardShowsItsDetails() {
        let app = launchApp()
        XCTAssertTrue(app.text("City Road").waitForExistence(timeout: shortWait))

        app.text("City Road").tap()

        // Playback needs the network, so only the text is checked.
        XCTAssertTrue(app.text("A short view of a road in the city.").waitForExistence(timeout: shortWait))
        XCTAssertTrue(app.text("City Road").exists)
        XCTAssertTrue(app.navigationBars.buttons["Save to favourites"].exists, "The heart sits in the navigation bar")
        XCTAssertTrue(app.heart(for: "City Road", saved: false).exists)
    }
}
