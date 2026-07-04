import XCTest

/// End-to-end smoke tests driven on the watchOS simulator. These are the
/// canonical way to verify session flows without touching the Simulator UI
/// by hand (screen-coordinate clicking is unreliable from the CLI).
final class SessionFlowUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchToHome() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        grantHealthAccessIfAsked(app)
        XCTAssertTrue(app.staticTexts["Resonance"].waitForExistence(timeout: 10),
                      "home list should show the Resonance preset")
        return app
    }

    /// The Health access sheet appears on first launch after install.
    /// It runs in-process enough for XCUITest to reach its buttons.
    private func grantHealthAccessIfAsked(_ app: XCUIApplication) {
        let review = app.buttons["Review"]
        guard review.waitForExistence(timeout: 5) else { return }
        review.tap()

        // One "Allow All"-style page per read/write section; enable everything.
        for _ in 0..<4 {
            let allowAll = app.switches.firstMatch
            if allowAll.waitForExistence(timeout: 3), (allowAll.value as? String) == "0" {
                allowAll.tap()
            }
            let next = app.buttons["Next"].exists ? app.buttons["Next"]
                : app.buttons["Allow"].exists ? app.buttons["Allow"]
                : app.buttons["Done"]
            if next.waitForExistence(timeout: 3) {
                next.tap()
            } else {
                break
            }
            if app.staticTexts["Resonance"].exists { break }
        }
    }

    func testHomeListsAllFiveProtocols() {
        let app = launchToHome()
        // watchOS lists render rows lazily; scroll to materialize each one.
        for name in ["Resonance", "Box Breathing", "Physiological Sigh", "Wim Hof", "Meditation"] {
            let row = app.staticTexts[name].firstMatch
            var swipes = 0
            while !row.exists && swipes < 6 {
                app.swipeUp()
                swipes += 1
            }
            XCTAssertTrue(row.exists, "\(name) should be listed")
        }
    }

    func testResonanceSessionRunsAndWritesSummary() {
        let app = launchToHome()
        app.staticTexts["Resonance"].firstMatch.tap()

        let start = app.buttons["Start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5), "config view should show Start")
        start.tap()

        // Session running: phase label should cycle between Inhale and Exhale.
        let inhale = app.staticTexts["Inhale"]
        let exhale = app.staticTexts["Exhale"]
        XCTAssertTrue(inhale.waitForExistence(timeout: 10) || exhale.exists,
                      "resonance visual should show a breath phase")

        // At 5.5 BPM a half-breath is ~5.5s; wait through a transition.
        let other = inhale.exists ? exhale : inhale
        XCTAssertTrue(other.waitForExistence(timeout: 12),
                      "phase should transition inhale <-> exhale")

        // End early and land on the summary.
        let end = app.buttons["End"]
        XCTAssertTrue(end.waitForExistence(timeout: 5))
        end.tap()

        XCTAssertTrue(app.staticTexts["Duration"].waitForExistence(timeout: 15),
                      "summary should appear after ending the session")

        let saved = app.staticTexts["Saved to Health"]
        let notSaved = app.staticTexts["Not saved to Health"]
        XCTAssertTrue(saved.waitForExistence(timeout: 10) || notSaved.exists,
                      "summary should report the Health write outcome")
        XCTAssertTrue(saved.exists, "mindful sample should have been saved to Health")

        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["Resonance"].waitForExistence(timeout: 10),
                      "Done should return home")
    }

    func testWimHofRetentionAdvancesOnTap() {
        let app = launchToHome()

        // Wim Hof is below the fold on the 44mm screen.
        let wimHof = app.staticTexts["Wim Hof"].firstMatch
        var swipes = 0
        while !(wimHof.exists && wimHof.isHittable) && swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
        wimHof.tap()

        let start = app.buttons["Start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()

        XCTAssertTrue(app.staticTexts["Round 1/3"].waitForExistence(timeout: 10),
                      "round indicator should show")

        // Hyperventilation: 35 breaths at 0.85s halves ≈ 60s, then retention.
        let retentionHint = app.staticTexts["Hold — tap when you\nneed to breathe"]
        XCTAssertTrue(retentionHint.waitForExistence(timeout: 90),
                      "retention phase should follow the fast breaths")

        retentionHint.tap()

        XCTAssertTrue(app.staticTexts["Deep inhale — hold"].waitForExistence(timeout: 10),
                      "tap during retention should advance to the recovery hold")

        app.buttons["End"].tap()
        XCTAssertTrue(app.staticTexts["Duration"].waitForExistence(timeout: 15))
    }
}
