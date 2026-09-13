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
        XCTAssertEqual(app.staticTexts["matchStatus"].label, "Round 2 · Grace leads 0", "Lowest Total leads in Skyjo")

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
        XCTAssertTrue(rows.element(boundBy: 1).label.contains("Grace won · 9"))

        // Listed below, but still the last Match started: its Players come picked.
        openSetup("Skyjo")
        XCTAssertTrue(app.buttons["player.Ada"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["player.Ada"].isSelected)
        XCTAssertTrue(app.buttons["player.Grace"].isSelected)
        XCTAssertFalse(app.buttons["player.Linus"].isSelected)
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
        XCTAssertTrue(row.label.contains("Linus won · 4"))
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

    func testTheDealPassesEachRoundAndCanBeHandedToSomeoneElse() throws {
        launch()
        passTheDealInTarot()
        attachScreenshot(named: "Dealer, portrait")
    }

    func testDealerTrackingWorksInLandscape() throws {
        launch(in: .landscapeLeft)
        passTheDealInTarot()
        attachScreenshot(named: "Dealer, landscape")
    }

    func testSettingUpABeloteMatchComposesTeamsAndScoresARound() throws {
        launch()
        composeBeloteTeamsAndScoreARound()
        attachScreenshot(named: "Belote scorepad, portrait")
    }

    func testBeloteTeamsWorkInLandscape() throws {
        launch(in: .landscapeLeft)
        composeBeloteTeamsAndScoreARound()
        attachScreenshot(named: "Belote scorepad, landscape")
    }

    func testAGameThatDoesNotTrackTheDealerShowsNone() throws {
        launch()
        setUpMatch("Scrabble", players: ["Ada", "Grace"])
        XCTAssertFalse(app.segmentedControls["rotationPicker"].exists, "Scrabble has no Dealer to pass")
        tapStart()

        press("5", "next", "next")

        XCTAssertFalse(app.buttons["dealer.1"].exists)
        XCTAssertFalse(app.buttons["dealer.2"].exists)
    }

    func testPointsTalliesWithPlusMinusAndTheKeypad() throws {
        launch()
        startMatch("Points", players: ["Ada", "Grace"])
        scorePointsWithPlusMinusAndTheKeypad()
        attachScreenshot(named: "Tally, portrait")

        // A Score is corrected from the history, like any other.
        scrollToReveal(app.buttons["history.4"])
        app.buttons["history.4"].tap()
        press("2", "0", "next")
        XCTAssertEqual(total(1), "19")
        attachScreenshot(named: "Tally history, portrait")

        backToList()
        let row = app.buttons["matchRow"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["matchStatus"].label, "Grace leads 19", "A Tally has no Round to report")
        row.tap()
        XCTAssertTrue(app.staticTexts["total.1"].waitForExistence(timeout: 5), "A Tally Match reopens on the Tally view")
        XCTAssertEqual(total(0), "3")
        XCTAssertEqual(total(1), "19")
    }

    func testTallyingAndEndingPointsInLandscape() throws {
        launch(in: .landscapeLeft)
        startMatch("Points", players: ["Ada", "Grace", "Linus"])
        scorePointsWithPlusMinusAndTheKeypad()
        attachScreenshot(named: "Tally, landscape")

        app.buttons["endMatchButton"].tap()
        confirmEndMatch()

        let outcome = element("outcome")
        XCTAssertTrue(outcome.waitForExistence(timeout: 5))
        XCTAssertTrue(outcome.label.contains("Grace wins"))
        XCTAssertFalse(app.buttons["plus.0"].exists, "No Score is added to an ended Match")
        attachScreenshot(named: "Tally ended, landscape")
    }

    func testFirstLaunchOffersTheGamesAndACardStartsItsSetup() throws {
        launch()
        startSetupFromAGameCard("Tarot")
    }

    func testFirstLaunchWorksInLandscape() throws {
        launch(in: .landscapeLeft)
        startSetupFromAGameCard("Skyjo")
    }

    func testMatchRowsShowTheStandingOrTheWinnerAndHandleTies() throws {
        launch()
        listATiedMatchInPlayAndATiedFinishedOne()
        attachScreenshot(named: "Match list, portrait")
    }

    func testMatchRowsWorkInLandscape() throws {
        launch(in: .landscapeLeft)
        listATiedMatchInPlayAndATiedFinishedOne()
        attachScreenshot(named: "Match list with ties, landscape")
    }

    // MARK: Helpers

    /// With no Matches, every built-in Game is a card, New Match sits at the
    /// bottom, and a card opens setup straight on its Game's Players.
    private func startSetupFromAGameCard(_ game: String) {
        for name in ["Belote", "Tarot", "Rami", "Skyjo", "Scrabble", "Points"] {
            XCTAssertTrue(app.buttons["gameCard.\(name)"].waitForExistence(timeout: 10), "No card for \(name)")
        }
        XCTAssertFalse(app.buttons["matchRow"].exists)
        assertNewMatchIsPinnedToTheBottom()
        attachScreenshot(named: "First launch, \(XCUIDevice.shared.orientation.isLandscape ? "landscape" : "portrait")")

        tapGameCard(game)

        XCTAssertTrue(app.navigationBars[game].waitForExistence(timeout: 5), "Setup opens on \(game)")
        XCTAssertTrue(app.textFields["newPlayerName"].waitForExistence(timeout: 5))
        pickPlayers(["Ada", "Grace", "Linus"])
        tapStart()

        backToList()
        XCTAssertTrue(app.buttons["matchRow"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["gameCard.\(game)"].exists, "The cards give way to the Match list")
        assertNewMatchIsPinnedToTheBottom()
    }

    /// Taps a Game's card and waits for its setup. Six Games overflow a small
    /// phone in landscape, and the grid scrolls under the New Match button
    /// pinned over it, so the card is scrolled clear first. A tap that lands on
    /// that button anyway opens the Game list instead: it is cancelled and the
    /// card tried once more, rather than failing on a mistimed scroll.
    private func tapGameCard(_ game: String) {
        let card = app.buttons["gameCard.\(game)"]
        let newMatch = app.buttons["newMatchButton"]
        XCTAssertTrue(card.waitForExistence(timeout: 10), "No card for \(game)")
        for attempt in 1...2 {
            for _ in 0..<5 where card.frame.maxY > newMatch.frame.minY {
                app.swipeUp()
            }
            card.tap()
            if app.navigationBars[game].waitForExistence(timeout: 5) { return }
            let cancel = app.buttons["cancelNewMatchButton"]
            XCTAssertTrue(
                cancel.exists,
                "Tapping \(game)'s card opened neither its setup nor the Game list"
            )
            cancel.tap()
            XCTAssertTrue(card.waitForExistence(timeout: 5))
            XCTAssertEqual(attempt, 1, "\(game)'s card never opened its setup")
        }
    }

    /// A Match tied in play above a Match that ended tied, each row saying so.
    private func listATiedMatchInPlayAndATiedFinishedOne() {
        startMatch("Skyjo", players: ["Linus", "Marie"])
        press("3", "next", "3", "next")
        app.buttons["endMatchButton"].tap()
        confirmEndMatch()
        XCTAssertTrue(element("outcome").waitForExistence(timeout: 5))
        backToList()

        startMatch("Skyjo", players: ["Ada", "Grace"])
        press("5", "next", "5")
        backToList()

        let today = Date.now.formatted(date: .abbreviated, time: .omitted)
        let rows = app.buttons.matching(identifier: "matchRow")
        XCTAssertTrue(rows.element(boundBy: 1).waitForExistence(timeout: 5))
        let statuses = app.staticTexts.matching(identifier: "matchStatus")
        XCTAssertEqual(statuses.element(boundBy: 0).label, "Round 1 · Ada and Grace tied on 5")
        XCTAssertEqual(statuses.element(boundBy: 1).label, "Linus and Marie tied · 3")
        XCTAssertTrue(rows.element(boundBy: 1).label.contains("Skyjo"))
        XCTAssertTrue(
            rows.element(boundBy: 1).label.contains(today),
            "A finished Match shows the day it ended"
        )
        XCTAssertFalse(rows.element(boundBy: 0).label.contains(today), "A Match in play shows no date")
        assertNewMatchIsPinnedToTheBottom()
    }

    private func assertNewMatchIsPinnedToTheBottom() {
        let newMatch = app.buttons["newMatchButton"]
        XCTAssertTrue(newMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(newMatch.isHittable)
        let window = app.windows.firstMatch.frame
        XCTAssertGreaterThan(newMatch.frame.minY, window.maxY - 120, "New Match sits at the bottom, within thumb reach")
    }

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

        // Grace's 9 in Round 1 was really a 30. With the keypad up, a small
        // phone only has room for the last Rounds, so put it away to see Round 1.
        app.buttons["hideKeypadButton"].tap()
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

    /// A counter-clockwise Tarot Match: the deal wraps from the first seat to
    /// the last, is handed to someone else, and passes on from them.
    private func passTheDealInTarot() {
        setUpMatch("Tarot", players: ["Ada", "Grace", "Linus"])
        let rotation = app.segmentedControls["rotationPicker"]
        XCTAssertTrue(rotation.exists)
        rotation.buttons["Counter-clockwise"].tap()
        tapStart()

        // With the keypad up, a small phone has room for hardly any Rounds, so
        // it is put away whenever the badges are read.
        hideKeypad()
        XCTAssertEqual(dealer(inRound: 1), "Ada", "Seat 1 deals first")
        app.buttons["score.1.0"].tap()
        press("1", "next", "next", "next")
        hideKeypad()
        XCTAssertEqual(dealer(inRound: 2), "Linus", "Counter-clockwise, the deal wraps round to the last seat")

        // A misdeal: Grace deals Round 2 instead.
        app.buttons["dealer.2"].tap()
        let grace = app.buttons["Grace"]
        XCTAssertTrue(grace.waitForExistence(timeout: 5))
        grace.tap()
        XCTAssertEqual(dealer(inRound: 2), "Grace")

        app.buttons["score.2.0"].tap()
        press("2", "next", "next", "next")
        hideKeypad()

        XCTAssertEqual(dealer(inRound: 3), "Ada", "The deal passes on from whoever was handed it")
        XCTAssertEqual(dealer(inRound: 1), "Ada", "Earlier Rounds keep their Dealer")
    }

    /// Belote, the first Game whose Teams hold more than one Player: four seats
    /// compose two Teams, a swap changes them, and the scorepad scores the Teams
    /// while the deal still passes Player by Player.
    private func composeBeloteTeamsAndScoreARound() {
        setUpMatch("Belote", players: ["Ada", "Grace", "Linus", "Marie"])
        dismissNameField()

        // Seats alternate, so partners sit across the table from each other.
        XCTAssertEqual(seat(team: 0, slot: 0).label, "Ada")
        XCTAssertEqual(seat(team: 0, slot: 1).label, "Linus")
        XCTAssertEqual(seat(team: 1, slot: 0).label, "Grace")
        XCTAssertEqual(seat(team: 1, slot: 1).label, "Marie")
        attachScreenshot(named: "Belote setup, \(orientationName)")

        // Ada would rather play with Grace: swapping their seats changes both Teams.
        bringIntoReach(seat(team: 0, slot: 1)).tap()
        let swap = app.buttons["Swap with Grace"]
        XCTAssertTrue(swap.waitForExistence(timeout: 5))
        swap.tap()
        XCTAssertEqual(seat(team: 0, slot: 1).label, "Grace")
        XCTAssertEqual(seat(team: 1, slot: 0).label, "Linus")

        tapStart()

        // Two columns, one per Team, labelled with their Players.
        XCTAssertTrue(app.staticTexts["teamName.0"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["teamName.0"].label, "Ada & Grace")
        XCTAssertEqual(app.staticTexts["teamName.1"].label, "Linus & Marie")
        XCTAssertFalse(app.staticTexts["teamName.2"].exists, "Four Players make two columns, not four")
        XCTAssertFalse(app.buttons["key.sign"].exists, "A Belote Team never scores below 0")

        // A Round splits its 162 points between the two Teams.
        press("9", "1", "next", "7", "1")

        XCTAssertEqual(total(0), "91")
        XCTAssertEqual(total(1), "71")
        XCTAssertTrue(app.images["leader.0"].exists, "Highest Total leads in Belote")

        hideKeypad()
        XCTAssertEqual(dealer(inRound: 1), "Ada", "Seat 1 deals first")

        app.buttons["newRoundButton"].tap()
        hideKeypad()
        XCTAssertEqual(dealer(inRound: 2), "Linus", "The deal passes to seat 2 — a Player on the other Team")
    }

    /// The Add Player field stays open for the next name; an empty submit puts
    /// it and the keyboard away, so the rest of the form is in reach.
    private func dismissNameField() {
        let field = app.textFields["newPlayerName"]
        guard field.exists else { return }
        field.typeText("\n")
        XCTAssertTrue(field.waitForNonExistence(timeout: 5))
    }

    private func seat(team: Int, slot: Int) -> XCUIElement {
        let menu = app.buttons["teamSeat.\(team).\(slot)"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5), "No seat \(slot) on Team \(team + 1)")
        return menu
    }

    /// Scrolls a Form down until the element can be tapped.
    @discardableResult
    private func bringIntoReach(_ element: XCUIElement) -> XCUIElement {
        for _ in 0..<4 where !element.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable, "\(element.identifier) never came into reach")
        return element
    }

    private var orientationName: String {
        XCUIDevice.shared.orientation.isLandscape ? "landscape" : "portrait"
    }

    private func hideKeypad() {
        let hide = app.buttons["hideKeypadButton"]
        XCTAssertTrue(hide.waitForExistence(timeout: 5))
        hide.tap()
        XCTAssertTrue(app.buttons["key.next"].waitForNonExistence(timeout: 5))
    }

    private func dealer(inRound number: Int) -> String? {
        let badge = app.buttons["dealer.\(number)"]
        XCTAssertTrue(badge.waitForExistence(timeout: 5), "No Dealer badge on Round \(number)")
        return badge.value as? String
    }

    /// Three +1 for Ada, a −1 then a keypad 12 for Grace, and no Round or
    /// Dealer anywhere.
    private func scorePointsWithPlusMinusAndTheKeypad() {
        XCTAssertFalse(app.buttons["key.next"].exists, "A Tally opens with the keypad away")
        XCTAssertFalse(app.buttons["newRoundButton"].exists)
        XCTAssertFalse(app.buttons["score.1.0"].exists, "A Tally has no Rounds")
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'Round' OR label CONTAINS[c] 'Dealer'")).firstMatch.exists)
        XCTAssertEqual(total(0), "0")

        tap("plus.0", "plus.0", "plus.0", "minus.1")
        XCTAssertEqual(total(0), "3")
        XCTAssertEqual(total(1), "-1")
        XCTAssertTrue(app.images["leader.0"].exists, "Highest Total leads in Points")

        tap("keypad.1")
        press("1", "2")
        XCTAssertEqual(total(1), "11", "The keypad lands its Score as typed")
        press("next")
        XCTAssertFalse(app.buttons["key.next"].exists, "Done puts the keypad away")

        let history = app.buttons["history.4"]
        XCTAssertFalse(history.exists, "The history sits behind a disclosure")
        let disclosure = element("history")
        scrollToReveal(disclosure)
        disclosure.tap()
        scrollToReveal(history)
        XCTAssertTrue(history.waitForExistence(timeout: 5))
        XCTAssertEqual(history.value as? String, "+12")
        XCTAssertEqual(app.buttons["history.3"].value as? String, "-1")
    }

    /// Scrolls the board down until the element is on screen: on a short
    /// landscape phone the history starts below the Teams, and its rows are
    /// only built once they scroll into view.
    private func scrollToReveal(_ element: XCUIElement) {
        for _ in 0..<5 where !(element.exists && element.isHittable) {
            app.scrollViews.firstMatch.swipeUp()
        }
    }

    private func tap(_ identifiers: String...) {
        for identifier in identifiers {
            let button = app.buttons[identifier]
            XCTAssertTrue(button.waitForExistence(timeout: 5), "No button \(identifier)")
            button.tap()
        }
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
        setUpMatch(game, players: players)
        tapStart()
    }

    /// Opens the Game's setup with exactly these Players picked, in this order.
    private func setUpMatch(_ game: String, players: [String]) {
        openSetup(game)
        pickPlayers(players)
    }

    /// Picks exactly these Players, in this order, on the setup already open.
    private func pickPlayers(_ players: [String]) {
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
    }

    private func tapStart() {
        app.buttons["startMatchButton"].tap()
        XCTAssertTrue(app.staticTexts["total.0"].waitForExistence(timeout: 5))
    }

    private func openSetup(_ game: String) {
        let newMatch = app.buttons["newMatchButton"]
        XCTAssertTrue(newMatch.waitForExistence(timeout: 10))
        newMatch.tap()

        // The list only builds rows on screen: a short landscape phone has to
        // scroll to reach the last Games.
        let gameRow = app.buttons["game.\(game)"]
        XCTAssertTrue(app.buttons["game.Tarot"].waitForExistence(timeout: 5))
        for _ in 0..<3 where !gameRow.isHittable {
            app.collectionViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(gameRow.waitForExistence(timeout: 5), "No Game \(game)")
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
