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

/// A running Match with its keypad docked under it, or beside it in landscape.
/// The keypad slides up from the bottom edge, or in from the trailing edge, as
/// it shows, and back out as it is put away, while the Match stretches or
/// shrinks to meet it. A plain fade under Reduce Motion.
struct KeypadDock<Content: View, Keypad: View>: View {
    let isShowingKeypad: Bool
    @ViewBuilder let content: Content
    @ViewBuilder let keypad: (Bool) -> Keypad
    @ScaledMetric(relativeTo: .body) private var minimumContentHeight: CGFloat = 240
    @State private var keypadHeight: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let usesSidebar = proxy.size.width >= 600 && proxy.size.width > proxy.size.height
            let compactKeys = proxy.size.height < (usesSidebar ? 500 : 720)
            if usesSidebar {
                HStack(spacing: 0) {
                    content
                    if isShowingKeypad {
                        HStack(spacing: 0) {
                            Divider()
                            ScrollView(.vertical) {
                                keypad(compactKeys)
                            }
                            .accessibilityIdentifier("keypadViewport")
                            .scrollBounceBehavior(.basedOnSize)
                            .frame(width: compactKeys ? 280 : 360)
                        }
                        .transition(transition(from: .trailing))
                    }
                }
            } else {
                VStack(spacing: 0) {
                    content
                    if isShowingKeypad {
                        VStack(spacing: 0) {
                            Divider()
                            ScrollView(.vertical) {
                                keypad(compactKeys)
                                    .frame(maxWidth: .infinity)
                                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                                        keypadHeight = $0
                                    }
                            }
                            .accessibilityIdentifier("keypadViewport")
                            .scrollBounceBehavior(.basedOnSize)
                            .frame(height: min(
                                keypadHeight > 0 ? keypadHeight : proxy.size.height / 2,
                                max(44, proxy.size.height - min(minimumContentHeight, proxy.size.height * 0.6))
                            ))
                        }
                        .transition(transition(from: .bottom))
                    }
                }
            }
        }
        // No bounce: overshooting would lift the keypad off the edge it slides from.
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.35), value: isShowingKeypad)
    }

    /// Faded as it slides, so no sliver of it lingers over the home indicator.
    private func transition(from edge: Edge) -> AnyTransition {
        reduceMotion ? .opacity : .move(edge: edge).combined(with: .opacity)
    }
}

/// The keypad Override — digits, sign and delete — with the Game's Quick scores
/// above it and −1 / +1 beside it, all aimed at the selected Score.
struct KeypadView<Target: KeypadTarget>: View {
    @Binding var target: Target
    let title: String
    let nextTitle: String
    var isCompact = false
    let next: () -> Void
    @ScaledMetric(relativeTo: .title2) private var adjustmentWidth: CGFloat = 72
    @ScaledMetric(relativeTo: .headline) private var quickScoreWidth: CGFloat = 44
    @State private var keypadWidth: CGFloat = 0

    private var keyHeight: CGFloat {
        isCompact ? 44 : 52
    }

    private var spacing: CGFloat {
        isCompact ? 6 : 8
    }

    private var adjustColumnWidth: CGFloat {
        keypadWidth >= 600 ? max(adjustmentWidth, (keypadWidth - 24 - spacing * 3) / 4) : adjustmentWidth
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
                    .lineLimit(2)
                    .accessibilityIdentifier("keypadTitle")
                Spacer()
                Text(target.keypadText)
                    .font(.title2.bold().monospacedDigit())
                    .accessibilityIdentifier("keypadDisplay")
                Button("Hide Keypad", systemImage: "keyboard.chevron.compact.down") { target.deselect() }
                    .labelStyle(.iconOnly)
                    .accessibilityIdentifier("hideKeypadButton")
            }
            if !quickScores.isEmpty && !isCompact {
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
            if isCompact && !quickScores.isEmpty {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: spacing) {
                        quickScoreButtons.fixedSize(horizontal: true, vertical: false)
                        nextButton.fixedSize(horizontal: true, vertical: false)
                    }
                    HStack(spacing: spacing) {
                        quickScoreButtons.fixedSize(horizontal: true, vertical: false)
                        compactNextButton
                    }
                    HStack(spacing: spacing) {
                        ScrollView(.horizontal) {
                            quickScoreButtons
                        }
                        .scrollIndicators(.hidden)
                        compactNextButton
                    }
                }
                .frame(maxWidth: .infinity)
            } else {
                nextButton
            }
        }
        .padding(12)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: {
            keypadWidth = $0
        }
        .background(.bar)
    }

    private var nextButton: some View {
        Button(action: next) {
            Text(nextTitle)
                .font(.headline)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: keyHeight - 8)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityIdentifier("key.next")
    }

    private var compactNextButton: some View {
        Button(action: next) {
            Image(systemName: nextSymbol)
                .font(.headline)
                .frame(width: keyHeight, height: keyHeight)
                .foregroundStyle(.white)
                .background(.tint, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(nextTitle)
        .accessibilityIdentifier("key.next")
    }

    private var nextSymbol: String {
        switch nextTitle {
        case "Done": "checkmark"
        case "New Round": "plus"
        default: "arrow.right"
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
                Button { target.enterQuickScore(points) } label: {
                    Text("\(points)")
                        .font(.headline.monospacedDigit())
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 6)
                        .frame(minWidth: quickScoreWidth, maxWidth: .infinity, minHeight: keyHeight)
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
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: keyHeight, maxHeight: fillsHeight ? .infinity : nil)
                .foregroundStyle(.primary)
                .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}
