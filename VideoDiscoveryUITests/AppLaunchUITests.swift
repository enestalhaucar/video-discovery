import XCTest

final class AppLaunchUITests: XCTestCase {
    @MainActor
    func testLaunchShowsDiscover() {
        let app = XCUIApplication()
        app.launchArguments += ["-catalog-stub", "loaded", "-favorites", "none"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Big Buck Bunny"].waitForExistence(timeout: 10))
    }
}
