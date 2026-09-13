import XCTest

// Acceptance-level UI behaviours. The scoring logic itself lives in Core, where
// `swift test` covers it fast; these tests prove the screens are wired to it.
@MainActor
final class FinalScoreUITests: XCTestCase {
    private lazy var app = XCUIApplication()

    func testScoringTwoSkyjoRoundsTotalsEachPlayer() throws {
        launch()
        startMatch("Skyjo", players: ["Ada", "Grace"])

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
        XCTAssertFalse(app.buttons["quickScore.0"].exists, "Skyjo declares no Quick scores")
        attachScreenshot(named: "Scorepad, portrait")
    }

    func testAMatchShowsAsInProgressAndResumesFromTheList() throws {
        launch()
        startMatch("Skyjo", players: ["Ada", "Grace"])
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
        startMatch("Skyjo", players: ["Ada", "Grace"])
        // Round 1 in full, then Round 2 left half scored: Ada has 8, Grace hasn't played.
        press("1", "2", "next", "5", "next", "8")
        backToList()
        startMatch("Skyjo", players: ["Linus", "Marie"])
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
        startMatch("Skyjo", players: ["Ada", "Grace", "Linus"])

        press("4", "next", "1", "1", "next", "6")

        XCTAssertEqual(total(0), "4")
        XCTAssertEqual(total(1), "11")
        XCTAssertEqual(total(2), "6")
        XCTAssertFalse(app.buttons["quickScore.0"].exists, "Skyjo declares no Quick scores")
        attachScreenshot(named: "Scorepad, landscape")
    }

    func testCorrectingAnOldScoreAndDeletingARoundRecomputeTheTotals() throws {
        launch()
        correctAnOldScoreAndDeleteARound()
        attachScreenshot(named: "Scorepad after a deleted Round, portrait")
    }

    func testCorrectingAnOldScoreAndDeletingARoundWorkInLandscape() throws {
        launch(in: .landscapeLeft)
        correctAnOldScoreAndDeleteARound()
        attachScreenshot(named: "Scorepad after a deleted Round, landscape")
    }

    func testARoundOfAScorepadTooWideToSwipeIsDeletedFromItsMenu() throws {
        launch()
        // Five columns overflow a portrait iPhone, so a sideways drag scrolls.
        startMatch("Skyjo", players: ["Ada", "Grace", "Linus", "Marie", "Alan"])
        press("1", "next", "2", "next", "3", "next", "4", "next", "5", "next", "6")
        app.buttons["hideKeypadButton"].tap()

        app.buttons["score.1.0"].press(forDuration: 1)
        let delete = app.buttons["Delete Round"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()

        XCTAssertTrue(app.buttons["score.2.0"].waitForNonExistence(timeout: 5))
        XCTAssertEqual(app.buttons["score.1.0"].value as? String, "6", "Round 2 closes up to become Round 1")
        XCTAssertEqual(total(0), "6")
        XCTAssertEqual(total(1), "0")
    }

    func testPlayersStayOnTheRosterAndTheLastMatchsPlayersComePicked() throws {
        launch()
        startMatch("Skyjo", players: ["Grace", "Ada"])
        backToList()

        app.terminate()
        app.launch()
        openSetup("Skyjo")

        let (grace, ada) = (app.buttons["player.Grace"], app.buttons["player.Ada"])
        XCTAssertTrue(grace.waitForExistence(timeout: 5), "The roster should survive the kill")
        XCTAssertTrue(grace.isSelected)
        XCTAssertTrue(ada.isSelected)
        attachScreenshot(named: "Match setup, portrait")

        app.buttons["startMatchButton"].tap()

        XCTAssertTrue(app.staticTexts["teamName.0"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["teamName.0"].label, "Grace", "Players keep the last Match's seats")
        XCTAssertEqual(app.staticTexts["teamName.1"].label, "Ada")
    }

    func testRenamingOrDeletingAPlayerLeavesTheirMatchAsItWas() throws {
        launch(in: .landscapeLeft)
        startMatch("Skyjo", players: ["Ada", "Grcae"])
        press("1", "2", "next", "5")
        backToList()
        openSetup("Skyjo")

        let typo = app.buttons["player.Grcae"]
        XCTAssertTrue(typo.waitForExistence(timeout: 5))
        typo.swipeLeft()
        app.buttons["Rename"].tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        let field = alert.textFields.firstMatch
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 5) + "Grace")
        alert.buttons.matching(identifier: "confirmRenameButton").element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["player.Grace"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["player.Grace"].isSelected, "A rename keeps the Player picked")

        app.buttons["player.Ada"].swipeLeft()
        app.buttons["Delete"].tap()
        XCTAssertTrue(app.buttons["player.Ada"].waitForNonExistence(timeout: 5))
        attachScreenshot(named: "Match setup, landscape")

        app.buttons["BackButton"].tap()
        let cancel = app.buttons["cancelNewMatchButton"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        cancel.tap()
        let row = app.buttons["matchRow"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()

        XCTAssertTrue(app.staticTexts["total.0"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["teamName.0"].label, "Ada")
        XCTAssertEqual(app.staticTexts["teamName.1"].label, "Grcae", "A Match keeps the names it was played under")
        XCTAssertEqual(total(0), "12")
        XCTAssertEqual(total(1), "5")
    }

    func testAQuickScoreThenPlusOneEntersAScore() throws {
        launch()
        scoreTarotWithQuickScores()
        attachScreenshot(named: "Quick scores, portrait")
    }

    func testQuickScoresWorkInLandscape() throws {
        launch(in: .landscapeLeft)
        scoreTarotWithQuickScores()
        attachScreenshot(named: "Quick scores, landscape")
    }

    // MARK: Helpers

    /// Scores three Rounds of Skyjo, retypes a Score from the first and deletes
    /// the second, checking the Totals, the leader and the Round numbers.
    private func correctAnOldScoreAndDeleteARound() {
        startMatch("Skyjo", players: ["Ada", "Grace"])
        press("4", "next", "9", "next")
        press("2", "0", "next", "2", "next")
        press("5", "next", "5", "next")
        XCTAssertEqual(total(0), "29")
        XCTAssertEqual(total(1), "16")
        XCTAssertTrue(app.images["leader.1"].exists, "Lowest Total leads in Skyjo")

        // Grace's 9 in Round 1 was really a 30.
        app.buttons["score.1.1"].tap()
        XCTAssertEqual(app.staticTexts["keypadDisplay"].label, "9")
        press("3", "0")

        XCTAssertEqual(total(1), "37")
        XCTAssertTrue(app.images["leader.0"].exists, "The correction hands Ada the lead")
        XCTAssertFalse(app.images["leader.1"].exists)
        XCTAssertFalse(app.buttons["score.5.0"].exists, "Correcting a Score never starts a Round")

        // Done on an earlier Round's last Team puts the keypad away.
        press("next")
        XCTAssertTrue(app.buttons["key.next"].waitForNonExistence(timeout: 5))

        // Round 2 was misdealt.
        app.buttons["score.2.0"].swipeLeft()
        let delete = app.buttons["Delete Round"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()

        XCTAssertTrue(app.buttons["score.4.0"].waitForNonExistence(timeout: 5))
        XCTAssertEqual(app.buttons["score.2.0"].value as? String, "5", "Round 3 closes up to become Round 2")
        XCTAssertEqual(app.buttons["score.3.0"].value as? String, "Not scored")
        XCTAssertEqual(total(0), "9")
        XCTAssertEqual(total(1), "35")
        XCTAssertTrue(app.images["leader.0"].exists)
    }

    /// Tarot's Quick scores in order, one nudged by ±1, and the keypad taking
    /// over from another.
    private func scoreTarotWithQuickScores() {
        startMatch("Tarot", players: ["Ada", "Grace", "Linus"])

        let quickScores = (0..<4).map { app.buttons["quickScore.\($0)"] }
        XCTAssertEqual(quickScores.map(\.label), ["25", "50", "100", "150"])
        XCTAssertFalse(app.buttons["quickScore.4"].exists)

        // Ada: a Quick score, nudged up.
        quickScores[1].tap()
        press("plusOne", "plusOne")
        XCTAssertEqual(app.staticTexts["keypadDisplay"].label, "52")
        press("next")
        // Grace: a Quick score typed over — the keypad ignores Quick scores.
        quickScores[0].tap()
        press("3", "7", "next")
        // Linus: nothing yet, then −1.
        press("minusOne")

        XCTAssertEqual(app.buttons["score.1.0"].value as? String, "52")
        XCTAssertEqual(total(0), "52")
        XCTAssertEqual(total(1), "37")
        XCTAssertEqual(total(2), "-1")
    }

    private func launch(in orientation: UIDeviceOrientation = .portrait) {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = orientation
        // Matches and Players are saved to disk, so each test gets a folder of
        // its own and starts with neither. Relaunching keeps the same folder.
        app.launchEnvironment["DATA_FOLDER"] = "UITests-\(UUID().uuidString)"
        app.launch()
    }

    private func startMatch(_ game: String, players: [String]) {
        openSetup(game)

        // Unpick whoever the last Match left picked but isn't playing this one.
        // Identifiers are read up front: the query shrinks with every unpick.
        let picked = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH 'player.' AND selected == true"))
            .allElementsBoundByIndex.map(\.identifier)
        for identifier in picked where !players.map({ "player.\($0)" }).contains(identifier) {
            app.buttons[identifier].tap()
        }

        for name in players {
            let row = app.buttons["player.\(name)"]
            if row.exists {
                if !row.isSelected { row.tap() }
                continue
            }
            let field = app.textFields["newPlayerName"]
            if !field.exists {
                app.buttons["addPlayerButton"].tap()
            }
            XCTAssertTrue(field.waitForExistence(timeout: 5))
            field.tap()
            field.typeText("\(name)\n")
            XCTAssertTrue(row.waitForExistence(timeout: 5), "\(name) should join the roster")
        }

        app.buttons["startMatchButton"].tap()
        XCTAssertTrue(app.buttons["key.next"].waitForExistence(timeout: 5))
    }

    private func openSetup(_ game: String) {
        let newMatch = app.buttons["newMatchButton"]
        XCTAssertTrue(newMatch.waitForExistence(timeout: 10))
        newMatch.tap()

        let gameRow = app.buttons["game.\(game)"]
        XCTAssertTrue(gameRow.waitForExistence(timeout: 5))
        gameRow.tap()
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
