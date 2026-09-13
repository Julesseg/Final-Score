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

    func testSkyjoAnnouncesATotalCrossing100AndTheLowestTotalWins() throws {
        launch()
        // An older Match left in progress, to be listed above the finished one.
        startMatch("Skyjo", players: ["Linus", "Marie"])
        press("4")
        backToList()

        startMatch("Skyjo", players: ["Ada", "Grace"])
        press("1", "0", "4", "next", "9", "next")

        let notice = element("endConditionNotice")
        XCTAssertTrue(notice.waitForExistence(timeout: 5), "Ada crossing 100 is announced")
        XCTAssertTrue(notice.label.contains("Grace would win"))

        // Scoring past the End condition stays possible.
        press("3")
        XCTAssertEqual(total(0), "107")
        XCTAssertTrue(notice.exists)
        attachScreenshot(named: "End condition announced, portrait")

        app.buttons["endMatchFromNotice"].tap()
        confirmEndMatch()

        let outcome = element("outcome")
        XCTAssertTrue(outcome.waitForExistence(timeout: 5))
        XCTAssertTrue(outcome.label.contains("Grace wins"))
        XCTAssertFalse(app.buttons["key.next"].exists, "Ending puts the keypad away")

        backToList()

        let rows = app.buttons.matching(identifier: "matchRow")
        XCTAssertTrue(rows.element(boundBy: 1).waitForExistence(timeout: 5))
        XCTAssertTrue(rows.element(boundBy: 0).label.contains("Linus"), "In progress is listed above finished")
        XCTAssertTrue(rows.element(boundBy: 1).label.contains("Ada"))
        XCTAssertTrue(rows.element(boundBy: 1).label.contains("Finished"))
        XCTAssertTrue(rows.element(boundBy: 1).label.contains("Grace wins"))
    }

    func testEndingAMatchInLandscape() throws {
        launch(in: .landscapeLeft)
        startMatch("Skyjo", players: ["Ada", "Grace", "Linus"])
        press("1", "0", "6", "next", "4", "next", "4", "next")

        let notice = element("endConditionNotice")
        XCTAssertTrue(notice.waitForExistence(timeout: 5), "The announcement shows in landscape too")
        XCTAssertTrue(notice.label.contains("Grace and Linus would tie"))
        XCTAssertTrue(app.buttons["endMatchFromNotice"].isHittable)
        attachScreenshot(named: "End condition announced, landscape")

        // Ending manually from the toolbar works too.
        let endMatch = app.buttons["endMatchButton"]
        XCTAssertTrue(endMatch.waitForExistence(timeout: 5))
        endMatch.tap()
        confirmEndMatch()

        let outcome = element("outcome")
        XCTAssertTrue(outcome.waitForExistence(timeout: 5))
        XCTAssertTrue(outcome.label.contains("Grace and Linus tie"))
        XCTAssertFalse(endMatch.exists)
        attachScreenshot(named: "Match ended, landscape")

        // Correcting an old Score corrects the Winner.
        app.buttons["score.1.1"].tap()
        press("7")
        XCTAssertTrue(outcome.label.contains("Linus wins"))

        backToList()
        let row = app.buttons["matchRow"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Finished"))
        XCTAssertTrue(row.label.contains("Linus wins"))
        attachScreenshot(named: "Match list, landscape")
    }

    func testAMatchCanBeEndedBeforeItsEndCondition() throws {
        launch()
        startMatch("Skyjo", players: ["Ada", "Grace"])
        press("6", "next", "4")

        app.buttons["endMatchButton"].tap()
        confirmEndMatch()

        let outcome = element("outcome")
        XCTAssertTrue(outcome.waitForExistence(timeout: 5))
        XCTAssertTrue(outcome.label.contains("Grace wins"))
        XCTAssertFalse(element("endConditionNotice").exists)
    }

    // MARK: Helpers

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
        // Wait out the pop, so the next tap lands on the list rather than mid-transition.
        XCTAssertTrue(app.navigationBars["Matches"].waitForExistence(timeout: 5))
    }

    private func press(_ keys: String...) {
        for key in keys {
            let button = app.buttons["key.\(key)"]
            XCTAssertTrue(button.waitForExistence(timeout: 5), "No key \(key)")
            button.tap()
        }
    }

    private func confirmEndMatch() {
        let confirm = app.alerts.buttons["End Match"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
    }

    /// An element by identifier, whatever type its combined children expose it as.
    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
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
