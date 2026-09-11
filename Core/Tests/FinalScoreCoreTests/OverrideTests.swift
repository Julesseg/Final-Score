import Testing
@testable import FinalScoreCore

@Suite("Keypad Override")
struct OverrideTests {
    @Test func anUntouchedOverrideReadsAsZero() {
        let override = Override()
        #expect(override.points == 0)
        #expect(override.text == "0")
    }

    @Test func digitsBuildTheNumberLeftToRight() {
        var override = Override()
        override.type(1)
        override.type(2)
        #expect(override.points == 12)
        #expect(override.text == "12")
    }

    @Test func leadingZerosAreDropped() {
        var override = Override()
        override.type(0)
        override.type(0)
        override.type(7)
        #expect(override.text == "7")
    }

    @Test func signToggleMakesTheScoreNegative() {
        var override = Override()
        override.toggleSign()
        override.type(3)
        #expect(override.points == -3)
        #expect(override.text == "-3")

        override.toggleSign()
        #expect(override.points == 3)
    }

    @Test func deleteRemovesTheLastDigit() {
        var override = Override()
        override.type(4)
        override.type(2)
        override.deleteBackward()
        #expect(override.points == 4)
        override.deleteBackward()
        #expect(override.points == 0)
        #expect(override.text == "0")
    }

    @Test func typingOverAnExistingScoreReplacesIt() {
        var override = Override(points: 12)
        #expect(override.text == "12")

        override.type(5)

        #expect(override.points == 5)
    }

    @Test func signToggleNegatesAnExistingScore() {
        var override = Override(points: 12)
        override.toggleSign()
        #expect(override.points == -12)
    }

    @Test func deleteEditsAnExistingScore() {
        var override = Override(points: -12)
        override.deleteBackward()
        #expect(override.points == -1)
    }

    @Test func stopsAtSixDigits() {
        var override = Override()
        for digit in [1, 2, 3, 4, 5, 6, 7] {
            override.type(digit)
        }
        #expect(override.points == 123_456)
    }
}
