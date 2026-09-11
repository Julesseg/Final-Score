import SwiftUI

/// The keypad Override: digits, sign and delete for the selected cell.
struct KeypadView: View {
    let title: String
    let text: String
    let allowsNegative: Bool
    let nextTitle: String
    let onDigit: (Int) -> Void
    let onDelete: () -> Void
    let onToggleSign: () -> Void
    let onNext: () -> Void
    let onDismiss: () -> Void

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
                Text(text)
                    .font(.title2.bold().monospacedDigit())
                    .accessibilityIdentifier("keypadDisplay")
                Button("Hide Keypad", systemImage: "keyboard.chevron.compact.down", action: onDismiss)
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
                    if allowsNegative {
                        key("±", identifier: "key.sign", action: onToggleSign)
                            .accessibilityLabel("Change sign")
                    } else {
                        Color.clear.frame(height: keyHeight)
                    }
                    digitKey(0)
                    key(Image(systemName: "delete.left"), identifier: "key.delete", action: onDelete)
                        .accessibilityLabel("Delete")
                }
            }
            Button(action: onNext) {
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

    private func digitKey(_ digit: Int) -> some View {
        key("\(digit)", identifier: "key.\(digit)") { onDigit(digit) }
    }

    private func key(_ label: String, identifier: String, action: @escaping () -> Void) -> some View {
        key(Text(label), identifier: identifier, action: action)
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
