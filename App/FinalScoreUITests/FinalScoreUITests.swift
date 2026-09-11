import XCTest

// Acceptance-level UI behaviours. The scoring logic itself lives in Core, where
// `swift test` covers it fast; these tests prove the screens are wired to it.
@MainActor
final class FinalScoreUITests: XCTestCase {
    private lazy var app = XCUIApplication()

    func testScoringTwoSkyjoRoundsTotalsEachPlayer() throws {
        launch()
        startSkyjoMatch(players: ["Ada", "Grace"])

        // Round 1 opens on Ada.
        press("1", "2", "next", "5", "next")
        // "New Round" after the last Player: Round 2 opens on Ada.
        press("3", "sign", "next")

        XCTAssertTrue(app.staticTexts["partialTotalsNotice"].exists)
        XCTAssertEqual(total(0), "9")

        press("2", "0")

        XCTAssertEqual(total(0), "9")
        XCTAssertEqual(total(1), "25")
        XCTAssertFalse(app.staticTexts["partialTotalsNotice"].exists)
        XCTAssertTrue(app.images["leader.0"].exists, "Lowest Total leads in Skyjo")
        XCTAssertEqual(app.buttons["score.2.0"].value as? String, "-3")
        attachScreenshot(named: "Scorepad, portrait")
    }

    func testAMatchShowsAsInProgressAndResumesFromTheList() throws {
        launch()
        startSkyjoMatch(players: ["Ada", "Grace"])
        press("7", "next", "next")

        backToList()

        let row = app.buttons["matchRow"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["matchStatus"].label.hasPrefix("In progress"))

        row.tap()

        XCTAssertTrue(app.staticTexts["total.0"].waitForExistence(timeout: 5))
        XCTAssertEqual(total(0), "7")
        XCTAssertEqual(total(1), "0", "Next on an untouched Score records an explicit 0")
        XCTAssertEqual(app.buttons["score.1.1"].value as? String, "0")
    }

    func testEveryMatchComesBackAfterAKillNewestFirst() throws {
        launch()
        startSkyjoMatch(players: ["Ada", "Grace"])
        // Round 1 in full, then Round 2 left half scored: Ada has 8, Grace hasn't played.
        press("1", "2", "next", "5", "next", "8")
        backToList()
        startSkyjoMatch(players: ["Linus", "Marie"])
        press("4")
        backToList()

        app.terminate()
        app.launch()

        let rows = app.buttons.matching(identifier: "matchRow")
        XCTAssertTrue(rows.element(boundBy: 1).waitForExistence(timeout: 10), "Both Matches should survive the kill")
        XCTAssertEqual(rows.count, 2)
        XCTAssertTrue(rows.element(boundBy: 0).label.contains("Linus"), "The Match started last is listed first")
        XCTAssertTrue(rows.element(boundBy: 1).label.contains("Ada"))

        rows.element(boundBy: 1).tap()

        XCTAssertTrue(app.staticTexts["total.0"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["score.1.0"].value as? String, "12")
        XCTAssertEqual(app.buttons["score.2.0"].value as? String, "8")
        XCTAssertEqual(app.buttons["score.2.1"].value as? String, "Not scored", "Round 2 is still half scored")
        XCTAssertEqual(total(0), "20")
        XCTAssertEqual(total(1), "5")
        XCTAssertTrue(app.staticTexts["partialTotalsNotice"].exists)
    }

    func testScoringWorksInLandscape() throws {
        launch(in: .landscapeLeft)
        startSkyjoMatch(players: ["Ada", "Grace", "Linus"])

        press("4", "next", "1", "1", "next", "6")

        XCTAssertEqual(total(0), "4")
        XCTAssertEqual(total(1), "11")
        XCTAssertEqual(total(2), "6")
        attachScreenshot(named: "Scorepad, landscape")
    }

    // MARK: Helpers

    private func launch(in orientation: UIDeviceOrientation = .portrait) {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = orientation
        // Matches are saved to disk now, so each test gets a folder of its own
        // and starts on an empty list. Relaunching keeps the same folder.
        app.launchEnvironment["MATCHES_FOLDER"] = "UITests-\(UUID().uuidString)"
        app.launch()
    }

    private func startSkyjoMatch(players: [String]) {
        let newMatch = app.buttons["newMatchButton"]
        XCTAssertTrue(newMatch.waitForExistence(timeout: 10))
        newMatch.tap()

        let skyjo = app.buttons["game.Skyjo"]
        XCTAssertTrue(skyjo.waitForExistence(timeout: 5))
        skyjo.tap()

        for (index, name) in players.enumerated() {
            if index >= 2 {
                app.buttons["addPlayerButton"].tap()
            }
            let field = app.textFields["playerName.\(index)"]
            XCTAssertTrue(field.waitForExistence(timeout: 5))
            field.tap()
            field.typeText(name)
        }

        app.buttons["startMatchButton"].tap()
        XCTAssertTrue(app.buttons["key.next"].waitForExistence(timeout: 5))
    }

    private func backToList() {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }

    private func press(_ keys: String...) {
        for key in keys {
            let button = app.buttons["key.\(key)"]
            XCTAssertTrue(button.waitForExistence(timeout: 5), "No key \(key)")
            button.tap()
        }
    }

    private func total(_ teamIndex: Int) -> String {
        app.staticTexts["total.\(teamIndex)"].label
    }

    /// Kept in the result bundle CI uploads, so a layout can be checked by eye.
    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
