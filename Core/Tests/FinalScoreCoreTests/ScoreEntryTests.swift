import Testing
@testable import FinalScoreCore

@Suite("Keypad entry")
struct ScoreEntryTests {
    @Test func anEmptyCellReadsAsZero() {
        let entry = ScoreEntry()
        #expect(entry.value == 0)
        #expect(entry.text == "0")
    }

    @Test func digitsBuildTheNumberLeftToRight() {
        var entry = ScoreEntry()
        entry.type(1)
        entry.type(2)
        #expect(entry.value == 12)
        #expect(entry.text == "12")
    }

    @Test func leadingZerosAreDropped() {
        var entry = ScoreEntry()
        entry.type(0)
        entry.type(0)
        entry.type(7)
        #expect(entry.text == "7")
    }

    @Test func signToggleMakesTheScoreNegative() {
        var entry = ScoreEntry()
        entry.toggleSign()
        entry.type(3)
        #expect(entry.value == -3)
        #expect(entry.text == "-3")

        entry.toggleSign()
        #expect(entry.value == 3)
    }

    @Test func deleteRemovesTheLastDigit() {
        var entry = ScoreEntry()
        entry.type(4)
        entry.type(2)
        entry.deleteBackward()
        #expect(entry.value == 4)
        entry.deleteBackward()
        #expect(entry.value == 0)
        #expect(entry.text == "0")
    }

    @Test func typingIntoAScoredCellReplacesItsScore() {
        var entry = ScoreEntry(points: 12)
        #expect(entry.text == "12")

        entry.type(5)

        #expect(entry.value == 5)
    }

    @Test func signToggleNegatesAScoredCell() {
        var entry = ScoreEntry(points: 12)
        entry.toggleSign()
        #expect(entry.value == -12)
    }

    @Test func deleteEditsAScoredCell() {
        var entry = ScoreEntry(points: -12)
        entry.deleteBackward()
        #expect(entry.value == -1)
    }

    @Test func stopsAtSixDigits() {
        var entry = ScoreEntry()
        for digit in [1, 2, 3, 4, 5, 6, 7] {
            entry.type(digit)
        }
        #expect(entry.value == 123_456)
    }
}
