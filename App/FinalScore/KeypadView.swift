import SwiftUI
import FinalScoreCore

/// What the keypad types into: the scorepad of a Rounds Match, or the Tally
/// pad of a Tally Match. What each key does is theirs to decide, in Core.
protocol KeypadTarget {
    var match: Match { get }
    var keypadText: String { get }
    mutating func type(_ digit: Int)
    mutating func deleteBackward()
    mutating func toggleSign()
    mutating func enterQuickScore(_ points: Int)
    mutating func adjust(by delta: Int)
    mutating func deselect()
}

extension Scorepad: KeypadTarget {}
extension TallyPad: KeypadTarget {}

/// The keypad Override — digits, sign and delete — with the Game's Quick scores
/// above it and −1 / +1 beside it, all aimed at the selected Score.
struct KeypadView<Target: KeypadTarget>: View {
    @Binding var target: Target
    /// Whose Score is being typed: "Grace · Round 2".
    let title: String
    /// The wide key under the digits, and what it does.
    let nextTitle: String
    let next: () -> Void
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// Landscape phones have the height for four rows of keys, or for five
    /// shorter ones once a row of Quick scores joins them.
    private var keyHeight: CGFloat {
        guard verticalSizeClass == .compact else { return 52 }
        return quickScores.isEmpty ? 40 : 32
    }

    private var spacing: CGFloat {
        verticalSizeClass == .compact ? 6 : 8
    }

    private var adjustColumnWidth: CGFloat {
        verticalSizeClass == .compact ? 56 : 72
    }

    private var quickScores: [Int] {
        target.match.game.quickScores
    }

    var body: some View {
        VStack(spacing: spacing) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .accessibilityIdentifier("keypadTitle")
                Spacer()
                Text(target.keypadText)
                    .font(.title2.bold().monospacedDigit())
                    .accessibilityIdentifier("keypadDisplay")
                Button("Hide Keypad", systemImage: "keyboard.chevron.compact.down") { target.deselect() }
                    .labelStyle(.iconOnly)
                    .accessibilityIdentifier("hideKeypadButton")
            }
            if !quickScores.isEmpty {
                quickScoreRow
            }
            HStack(spacing: spacing) {
                Grid(horizontalSpacing: spacing, verticalSpacing: spacing) {
                    ForEach([[1, 2, 3], [4, 5, 6], [7, 8, 9]], id: \.self) { digits in
                        GridRow {
                            ForEach(digits, id: \.self, content: digitKey)
                        }
                    }
                    GridRow {
                        if target.match.game.allowsNegative {
                            key(Text("±"), identifier: "key.sign") { target.toggleSign() }
                                .accessibilityLabel("Change sign")
                        } else {
                            Color.clear.frame(height: keyHeight)
                        }
                        digitKey(0)
                        key(Image(systemName: "delete.left"), identifier: "key.delete") { target.deleteBackward() }
                            .accessibilityLabel("Delete")
                    }
                }
                // Each spans two rows of digits: the keys most often tapped twice running.
                VStack(spacing: spacing) {
                    key(Text("+1"), identifier: "key.plusOne", fillsHeight: true) { target.adjust(by: 1) }
                        .accessibilityLabel("Add 1")
                    key(Text("−1"), identifier: "key.minusOne", fillsHeight: true) { target.adjust(by: -1) }
                        .accessibilityLabel("Subtract 1")
                }
                .frame(width: adjustColumnWidth)
            }
            // As tall as the digits, which the ±1 column then stretches to fill.
            .fixedSize(horizontal: false, vertical: true)
            Button(action: next) {
                Text(nextTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: keyHeight - 8)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("key.next")
        }
        .padding(12)
        .background(.bar)
    }

    /// The Game's Quick scores in the order it declares them, spread across the
    /// keypad when they fit and scrolling sideways when they don't.
    private var quickScoreRow: some View {
        ViewThatFits(in: .horizontal) {
            quickScoreButtons
            ScrollView(.horizontal) {
                quickScoreButtons
            }
            .scrollIndicators(.hidden)
        }
    }

    private var quickScoreButtons: some View {
        HStack(spacing: spacing) {
            ForEach(Array(quickScores.enumerated()), id: \.offset) { index, points in
                // Drawn by hand rather than `.bordered`, whose padding would
                // push even four short values into scrolling on a landscape keypad.
                Button { target.enterQuickScore(points) } label: {
                    Text("\(points)")
                        .font(.headline.monospacedDigit())
                        .padding(.horizontal, 6)
                        .frame(minWidth: 44, maxWidth: .infinity, minHeight: keyHeight)
                        .background(.tint.opacity(0.15), in: Capsule())
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("quickScore.\(index)")
            }
        }
    }

    private func digitKey(_ digit: Int) -> some View {
        key(Text("\(digit)"), identifier: "key.\(digit)") { target.type(digit) }
    }

    private func key(
        _ label: some View,
        identifier: String,
        fillsHeight: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            label
                .font(.title2.monospacedDigit())
                .frame(maxWidth: .infinity, minHeight: keyHeight, maxHeight: fillsHeight ? .infinity : nil)
        }
        .buttonStyle(.bordered)
        .tint(.secondary)
        .accessibilityIdentifier(identifier)
    }
}
