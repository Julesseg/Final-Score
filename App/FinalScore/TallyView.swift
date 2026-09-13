import SwiftUI
import FinalScoreCore

/// A Tally Match: one large Total per Team with − / + for thumbs, the keypad
/// for larger changes, and every Score recorded behind a History disclosure.
/// No Rounds and no Dealer. What each tap records is `TallyPad`'s business, in
/// Core.
struct TallyView: View {
    @Binding var match: Match
    @State private var pad: TallyPad
    @State private var isConfirmingEnd = false
    @State private var isShowingHistory = false
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    init(match: Binding<Match>) {
        _match = match
        _pad = State(initialValue: TallyPad(match: match.wrappedValue))
    }

    var body: some View {
        Group {
            if isCompact {
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        MatchBanner(match: pad.match) { isConfirmingEnd = true }
                        board
                    }
                    if pad.selection != nil {
                        Divider()
                        keypad
                            .frame(width: 280)
                    }
                }
            } else {
                VStack(spacing: 0) {
                    MatchBanner(match: pad.match) { isConfirmingEnd = true }
                    board
                    if pad.selection != nil {
                        Divider()
                        keypad
                    }
                }
            }
        }
        .tint(pad.match.game.accent.color)
        .animation(.default, value: pad.match.endConditionIsReached)
        .animation(.default, value: pad.match.isEnded)
        .navigationTitle(pad.match.game.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !pad.match.isEnded {
                ToolbarItem(placement: .primaryAction) {
                    Button("End Match", systemImage: "flag.checkered") { isConfirmingEnd = true }
                        .accessibilityIdentifier("endMatchButton")
                }
            }
        }
        .alert("End this Match?", isPresented: $isConfirmingEnd) {
            Button("Cancel", role: .cancel) {}
            Button("End Match") { pad.endMatch() }
        } message: {
            Text("Scores can still be corrected afterwards.")
        }
        .onChange(of: pad.match) { _, updated in
            match = updated
        }
    }

    private var teams: [Team] { pad.match.teams }
    private var isCompact: Bool { verticalSizeClass == .compact }

    // MARK: Board

    private var board: some View {
        ScrollViewReader { scroller in
            ScrollView {
                VStack(spacing: isCompact ? 12 : 16) {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: isCompact ? 220 : 300), spacing: 12)],
                        spacing: 12
                    ) {
                        ForEach(Array(teams.enumerated()), id: \.element.id) { index, team in
                            card(for: team, index: index)
                                .id(team.id)
                        }
                    }
                    history
                }
                .padding(isCompact ? 12 : 16)
            }
            // The keypad takes half the screen as it opens: keep the Team it
            // is typing for in view.
            .onChange(of: pad.selection) { _, selection in
                if case .newScore(let team) = selection {
                    withAnimation { scroller.scrollTo(team) }
                }
            }
        }
    }

    private func card(for team: Team, index: Int) -> some View {
        let total = pad.match.total(for: team.id)
        let isLeader = pad.match.leaders.contains { $0.id == team.id }
        let isSelected = pad.selectedTeam == team.id
        return VStack(spacing: isCompact ? 2 : 8) {
            HStack(spacing: 6) {
                Image(systemName: "crown.fill")
                    .font(.caption)
                    .foregroundStyle(.tint)
                    .opacity(isLeader ? 1 : 0)
                    .accessibilityHidden(!isLeader)
                    .accessibilityLabel("Leading")
                    .accessibilityIdentifier("leader.\(index)")
                Text(team.name)
                    .font(.headline)
                    .lineLimit(1)
                    .accessibilityIdentifier("teamName.\(index)")
                Spacer(minLength: 4)
                if !pad.match.isEnded {
                    Button("Enter Score", systemImage: "number") { pad.select(.newScore(team: team.id)) }
                        .labelStyle(.iconOnly)
                        .font(.title3)
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityLabel("Enter a Score for \(team.name)")
                        .accessibilityIdentifier("keypad.\(index)")
                }
            }
            HStack(spacing: 8) {
                if !pad.match.isEnded {
                    adjustButton(for: team, index: index, by: -1)
                }
                Text("\(total)")
                    .font(.system(size: isCompact ? 44 : 60, weight: .bold, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText(value: Double(total)))
                    .animation(.snappy, value: total)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("total.\(index)")
                if !pad.match.isEnded {
                    adjustButton(for: team, index: index, by: 1)
                }
            }
        }
        .padding(isCompact ? 10 : 14)
        .background {
            RoundedRectangle(cornerRadius: 16).fill(.fill.quaternary)
            if isSelected {
                RoundedRectangle(cornerRadius: 16).strokeBorder(.tint, lineWidth: 2)
            }
        }
    }

    /// Sized for thumbs: each tap records a Score of ±1.
    private func adjustButton(for team: Team, index: Int, by delta: Int) -> some View {
        let size: CGFloat = isCompact ? 52 : 64
        return Button {
            pad.adjustTotal(of: team.id, by: delta)
        } label: {
            Image(systemName: delta > 0 ? "plus" : "minus")
                .font(.title.bold())
                .frame(width: size, height: size)
                .background(.tint.opacity(0.15), in: Circle())
        }
        .buttonStyle(.borderless)
        .disabled(!pad.canAdjustTotal(of: team.id, by: delta))
        .accessibilityLabel(delta > 0 ? "Add 1 to \(team.name)" : "Subtract 1 from \(team.name)")
        .accessibilityIdentifier(delta > 0 ? "plus.\(index)" : "minus.\(index)")
    }

    // MARK: History

    /// Every Score recorded, newest first. Tapping one opens the keypad on it
    /// to correct it.
    private var history: some View {
        let scores = pad.match.tallyScores
        return DisclosureGroup(isExpanded: $isShowingHistory) {
            if scores.isEmpty {
                Text("No Scores yet")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(scores.indices.reversed(), id: \.self) { index in
                        historyRow(at: index)
                        Divider()
                    }
                }
            }
        } label: {
            HStack {
                Text("History")
                    .font(.headline)
                Text("\(scores.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("history")
    }

    private func historyRow(at index: Int) -> some View {
        let score = pad.match.tallyScores[index]
        let name = teams.first { $0.id == score.team }?.name ?? ""
        let points = score.points.formatted(.number.sign(strategy: .always()))
        let isSelected = pad.selection == .recorded(index)
        return Button {
            pad.select(.recorded(index))
        } label: {
            HStack {
                Text(name)
                    .lineLimit(1)
                Spacer()
                Text(points)
                    .font(.body.bold().monospacedDigit())
                if let total = pad.match.totalAfterTallyScore(at: index) {
                    Text("→ \(total)")
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 48, alignment: .trailing)
                }
            }
            .padding(.horizontal, 8)
            .frame(minHeight: 44)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8).fill(.tint.opacity(0.15))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityValue(points)
        .accessibilityIdentifier("history.\(index)")
    }

    // MARK: Keypad

    private var keypad: some View {
        KeypadView(
            target: $pad,
            title: pad.selectedTeam.flatMap { id in teams.first { $0.id == id } }?.name ?? "",
            nextTitle: "Done"
        ) { pad.deselect() }
    }
}
