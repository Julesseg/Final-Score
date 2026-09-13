import SwiftUI
import FinalScoreCore

/// The keypad Override — digits, sign and delete — with the Game's Quick scores
/// above it and −1 / +1 beside it, all aimed at the selected Score.
struct KeypadView: View {
    @Binding var scorepad: Scorepad
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
        scorepad.match.game.quickScores
    }

    var body: some View {
        VStack(spacing: spacing) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Text(scorepad.keypadText)
                    .font(.title2.bold().monospacedDigit())
                    .accessibilityIdentifier("keypadDisplay")
                Button("Hide Keypad", systemImage: "keyboard.chevron.compact.down") { scorepad.deselect() }
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
                        if scorepad.match.game.allowsNegative {
                            key(Text("±"), identifier: "key.sign") { scorepad.toggleSign() }
                                .accessibilityLabel("Change sign")
                        } else {
                            Color.clear.frame(height: keyHeight)
                        }
                        digitKey(0)
                        key(Image(systemName: "delete.left"), identifier: "key.delete") { scorepad.deleteBackward() }
                            .accessibilityLabel("Delete")
                    }
                }
                // Each spans two rows of digits: the keys most often tapped twice running.
                VStack(spacing: spacing) {
                    key(Text("+1"), identifier: "key.plusOne", fillsHeight: true) { scorepad.adjust(by: 1) }
                        .accessibilityLabel("Add 1")
                    key(Text("−1"), identifier: "key.minusOne", fillsHeight: true) { scorepad.adjust(by: -1) }
                        .accessibilityLabel("Subtract 1")
                }
                .frame(width: adjustColumnWidth)
            }
            // As tall as the digits, which the ±1 column then stretches to fill.
            .fixedSize(horizontal: false, vertical: true)
            Button { scorepad.next() } label: {
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

    /// "Grace · Round 2"
    private var title: String {
        guard let selection = scorepad.selection,
              let team = scorepad.match.teams.first(where: { $0.id == selection.team }),
              let round = scorepad.match.number(of: selection.round)
        else { return "" }
        return "\(team.name) · Round \(round)"
    }

    private var nextTitle: String {
        switch scorepad.nextStep {
        case .nextTeam: "Next"
        case .newRound: "New Round"
        case .done: "Done"
        }
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
                Button { scorepad.enterQuickScore(points) } label: {
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
        key(Text("\(digit)"), identifier: "key.\(digit)") { scorepad.type(digit) }
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
