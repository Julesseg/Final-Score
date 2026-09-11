import SwiftUI
import FinalScoreCore

/// The keypad Override: digits, sign and delete for the selected Score.
struct KeypadView: View {
    @Binding var scorepad: Scorepad
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var keyHeight: CGFloat {
        verticalSizeClass == .compact ? 40 : 52
    }

    var body: some View {
        VStack(spacing: 8) {
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
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
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

    private func digitKey(_ digit: Int) -> some View {
        key(Text("\(digit)"), identifier: "key.\(digit)") { scorepad.type(digit) }
    }

    private func key(_ label: some View, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            label
                .font(.title2.monospacedDigit())
                .frame(maxWidth: .infinity, minHeight: keyHeight)
        }
        .buttonStyle(.bordered)
        .tint(.secondary)
        .accessibilityIdentifier(identifier)
    }
}
