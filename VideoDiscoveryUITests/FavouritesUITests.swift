import XCTest

/// The Favourites tab, the hearts that feed it, and the navigation stacks of both tabs.
@MainActor
final class FavouritesUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testSavedVideosAreListedNewestFirst() {
        let app = launchApp(favorites: "sample")
        app.favouritesTab.tap()

        let titles = ["City Road", "Around the Park", "Big Buck Bunny"]
        let rows = titles.map { app.text($0) }
        XCTAssertTrue(rows[0].waitForExistence(timeout: shortWait))
        XCTAssertEqual(app.cells.count, 3)
        XCTAssertLessThan(rows[0].frame.minY, rows[1].frame.minY)
        XCTAssertLessThan(rows[1].frame.minY, rows[2].frame.minY)
    }

    func testSwipeToRemove() {
        let app = launchApp(favorites: "sample")
        app.favouritesTab.tap()
        let row = app.cells.containing(.staticText, identifier: "Around the Park").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: shortWait))

        row.swipeLeft()
        app.buttons["Remove"].tap()

        XCTAssertTrue(app.text("Around the Park").waitForDisappearance())
        XCTAssertEqual(app.cells.count, 2)
    }

    func testHeartRemovesWithoutOpeningTheVideo() {
        let app = launchApp(favorites: "sample")
        app.favouritesTab.tap()
        XCTAssertTrue(app.text("Big Buck Bunny").waitForExistence(timeout: shortWait))

        app.heart(for: "Big Buck Bunny", saved: true).tap()

        XCTAssertTrue(app.text("Big Buck Bunny").waitForDisappearance())
        XCTAssertEqual(app.cells.count, 2)
        XCTAssertTrue(app.navigationBars["Favourites"].exists, "Still on the list, not on the detail screen")
        XCTAssertFalse(app.text("A short animated sample featuring Big Buck Bunny.").exists)
    }

    func testEmptyStateBrowsesToDiscover() {
        let app = launchApp()
        app.favouritesTab.tap()

        XCTAssertTrue(app.text("No favourites yet").waitForExistence(timeout: shortWait))
        XCTAssertTrue(app.text("Tap the heart on any video to save it here.").exists)
        app.buttons["Browse videos"].tap()

        XCTAssertTrue(app.discoverTab.isSelected)
        XCTAssertTrue(app.text("Big Buck Bunny").waitForExistence(timeout: shortWait))
    }

    func testHeartOnADiscoverCardSavesTheVideo() {
        let app = launchApp()
        XCTAssertTrue(app.text("Buses by the Park").waitForExistence(timeout: shortWait))

        app.heart(for: "Buses by the Park", saved: false).tap()
        XCTAssertTrue(app.heart(for: "Buses by the Park", saved: true).waitForExistence(timeout: shortWait))
        XCTAssertTrue(app.text("Buses by the Park").exists, "The heart doesn't open the video")
        XCTAssertFalse(app.text("Buses passing beside a park.").exists)

        app.favouritesTab.tap()
        XCTAssertTrue(app.text("Buses by the Park").waitForExistence(timeout: shortWait))
        XCTAssertEqual(app.cells.count, 1)
    }

    func testEachTabKeepsItsNavigationStack() {
        let app = launchApp(favorites: "sample")
        XCTAssertTrue(app.text("Buses by the Park").waitForExistence(timeout: shortWait))

        app.text("Buses by the Park").tap()
        let discoverDetail = app.text("Buses passing beside a park.")
        XCTAssertTrue(discoverDetail.waitForExistence(timeout: shortWait))

        app.favouritesTab.tap()
        XCTAssertTrue(app.text("Around the Park").waitForExistence(timeout: shortWait))
        app.text("Around the Park").tap()
        let favouritesDetail = app.text("Roads, park scenery, and pedestrians.")
        XCTAssertTrue(favouritesDetail.waitForExistence(timeout: shortWait))

        app.discoverTab.tap()
        XCTAssertTrue(discoverDetail.waitForExistence(timeout: shortWait))
        XCTAssertFalse(favouritesDetail.exists)

        app.favouritesTab.tap()
        XCTAssertTrue(favouritesDetail.waitForExistence(timeout: shortWait))
        XCTAssertFalse(discoverDetail.exists)
    }
}
