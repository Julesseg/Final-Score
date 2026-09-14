import SwiftUI
import FinalScoreCore

/// A Game on its way into the custom Game form: a blank one, a copy of a
/// built-in, or a custom Game being edited.
struct GameFormRequest: Identifiable {
    let id = UUID()
    let draft: GameDraft
    /// The custom Game being edited; nil when the form saves a new one.
    let editing: CustomGame.ID?
}

/// The custom Game form: every setting a Game has, as plain controls (ADR-0002).
/// `GameDraft` keeps them coherent as they change, so Save only waits on a
/// name no other Game goes by.
struct GameFormView: View {
    let games: GameLibrary
    let editing: CustomGame.ID?
    @State private var draft: GameDraft
    /// Typed rather than bound to the draft, so the field can be cleared on the
    /// way to another number.
    @State private var targetText: String
    @State private var newQuickScore = ""
    @FocusState private var isTypingQuickScore: Bool
    @Environment(\.dismiss) private var dismiss

    init(games: GameLibrary, request: GameFormRequest) {
        self.games = games
        editing = request.editing
        _draft = State(initialValue: request.draft)
        _targetText = State(initialValue: request.draft.endCondition.target.map(String.init) ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                identitySection
                playersSection
                scoringSection
                endSection
                quickScoresSection
            }
            .navigationTitle(editing == nil ? "New Game" : "Edit Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("cancelGameButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                        .accessibilityIdentifier("saveGameButton")
                }
            }
        }
    }

    // MARK: Sections

    private var identitySection: some View {
        Section {
            HStack(spacing: 12) {
                GameSymbol(game: draft.game)
                TextField("Name", text: $draft.name)
                    .font(.headline)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .accessibilityIdentifier("gameName")
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 40), spacing: 8)], spacing: 8) {
                ForEach(Self.symbols, id: \.self) { symbol in
                    choice(isSelected: draft.symbol == symbol) {
                        draft.symbol = symbol
                    } label: {
                        Image(systemName: symbol)
                            .font(.title3)
                            .foregroundStyle(draft.accent.color)
                    }
                    .accessibilityLabel(symbol)
                    .accessibilityIdentifier("symbol.\(symbol)")
                }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 40), spacing: 8)], spacing: 8) {
                ForEach(Game.AccentToken.allCases, id: \.self) { accent in
                    choice(isSelected: draft.accent == accent) {
                        draft.accent = accent
                    } label: {
                        Circle()
                            .fill(accent.color.gradient)
                            .frame(width: 26, height: 26)
                    }
                    .accessibilityLabel(accent.rawValue.capitalized)
                    .accessibilityIdentifier("accent.\(accent.rawValue)")
                }
            }
        } footer: {
            if draft.hasName, !games.canSave(draft, replacing: editing) {
                Text("Another Game already goes by this name.")
            }
        }
    }

    private var playersSection: some View {
        Section {
            Toggle("Played in Teams", isOn: Binding(
                get: { draft.teamSize > 1 },
                set: { draft.teamSize = $0 ? 2 : 1 }
            ))
            .accessibilityIdentifier("teamsToggle")
            if draft.teamSize > 1 {
                Stepper(value: $draft.teamSize, in: 2...GameDraft.playerLimit / 2) {
                    LabeledContent("Players per Team", value: "\(draft.teamSize)")
                }
                .accessibilityIdentifier("teamSizeStepper")
            }
            Stepper(value: $draft.minPlayers, in: draft.playerCountRange, step: draft.teamSize) {
                LabeledContent("Fewest Players", value: "\(draft.minPlayers)")
            }
            .accessibilityIdentifier("minPlayersStepper")
            Stepper(value: $draft.maxPlayers, in: draft.playerCountRange, step: draft.teamSize) {
                LabeledContent("Most Players", value: "\(draft.maxPlayers)")
            }
            .accessibilityIdentifier("maxPlayersStepper")
        } header: {
            Text("Players")
        } footer: {
            if draft.teamSize > 1 {
                Text("Players count in whole Teams, with at least two Teams.")
            }
        }
    }

    private var scoringSection: some View {
        Section {
            Picker("Structure", selection: $draft.structure) {
                Text("Rounds").tag(Game.Structure.rounds)
                Text("Tally").tag(Game.Structure.tally)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("structurePicker")
            Picker("Wins", selection: $draft.direction) {
                Text("Highest Total").tag(Game.Direction.highWins)
                Text("Lowest Total").tag(Game.Direction.lowWins)
            }
            .accessibilityIdentifier("directionPicker")
            Toggle("Scores below 0", isOn: $draft.allowsNegative)
                .accessibilityIdentifier("negativeToggle")
            if draft.structure == .rounds {
                Toggle(
                    draft.teamSize > 1 ? "One Team scores each Round" : "One Player scores each Round",
                    isOn: Binding(
                        get: { draft.scorers == .oneTeamPerRound },
                        set: { draft.scorers = $0 ? .oneTeamPerRound : .everyone }
                    )
                )
                .accessibilityIdentifier("oneScorerToggle")
                Toggle("Track the Dealer", isOn: $draft.tracksDealer)
                    .accessibilityIdentifier("dealerToggle")
            }
        } header: {
            Text("Scoring")
        } footer: {
            Text(draft.structure == .rounds
                 ? "Each Round is one row of Scores."
                 : "A Tally keeps a running Total that Scores are added to as they happen.")
        }
    }

    private var endSection: some View {
        Section {
            Picker("Ends", selection: endKind) {
                Text("Never").tag(EndKind.none)
                Text("At a Total").tag(EndKind.targetTotal)
                if draft.structure == .rounds {
                    Text("After Rounds").tag(EndKind.roundCount)
                }
            }
            .accessibilityIdentifier("endConditionPicker")
            switch draft.endCondition {
            case .none:
                EmptyView()
            case .targetTotal:
                LabeledContent("Target Total") {
                    TextField("Target", text: $targetText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .accessibilityIdentifier("targetTotalField")
                }
                .onChange(of: targetText) { _, text in
                    if let target = Int(text) {
                        draft.endCondition = .targetTotal(target)
                    }
                }
            case .roundCount(let count):
                Stepper(value: roundCount, in: 1...999) {
                    LabeledContent("Rounds", value: "\(count)")
                }
                .accessibilityIdentifier("roundCountStepper")
            }
        } header: {
            Text("End")
        } footer: {
            if hasTarget {
                Text("The Match announces its end; scoring can go on past it.")
            } else {
                Text("Type a Target Total of at least 1.")
            }
        }
    }

    private var quickScoresSection: some View {
        Section {
            ForEach(draft.quickScores, id: \.self) { points in
                Text("\(points)")
                    .monospacedDigit()
                    .accessibilityIdentifier("customQuickScore.\(points)")
            }
            .onDelete { draft.removeQuickScores(atOffsets: $0) }
            TextField("Add a Quick score", text: $newQuickScore)
                .keyboardType(.numbersAndPunctuation)
                .focused($isTypingQuickScore)
                .submitLabel(.done)
                .onSubmit(addQuickScore)
                .accessibilityIdentifier("newQuickScore")
        } header: {
            Text("Quick scores")
        } footer: {
            Text("Offered as one tap on the scorepad, in ascending order. With none, the scorepad hides them. Swipe one to remove it.")
        }
    }

    // MARK: Helpers

    /// A name no other Game goes by, and a Target Total that is really typed:
    /// a field left blank or at 0 would save a target other than the one shown.
    private var canSave: Bool {
        games.canSave(draft, replacing: editing) && hasTarget
    }

    private var hasTarget: Bool {
        guard case .targetTotal = draft.endCondition else { return true }
        return (Int(targetText) ?? 0) >= 1
    }

    private enum EndKind: Hashable {
        case none, targetTotal, roundCount
    }

    /// Which End condition, remembering the target typed so far.
    private var endKind: Binding<EndKind> {
        Binding(
            get: {
                switch draft.endCondition {
                case .none: .none
                case .targetTotal: .targetTotal
                case .roundCount: .roundCount
                }
            },
            set: { kind in
                switch kind {
                case .none:
                    draft.endCondition = .none
                case .targetTotal:
                    let target = Int(targetText) ?? 100
                    targetText = String(target)
                    draft.endCondition = .targetTotal(target)
                case .roundCount:
                    draft.endCondition = .roundCount(10)
                }
            }
        )
    }

    private var roundCount: Binding<Int> {
        Binding(
            get: { if case .roundCount(let count) = draft.endCondition { count } else { 1 } },
            set: { draft.endCondition = .roundCount($0) }
        )
    }

    /// Adds the number typed, then stays open for the next one. Anything that
    /// isn't a whole number is left in the field to be corrected.
    private func addQuickScore() {
        guard let points = Int(newQuickScore.trimmingCharacters(in: .whitespaces)) else {
            isTypingQuickScore = !newQuickScore.isEmpty
            return
        }
        draft.addQuickScore(points)
        newQuickScore = ""
        isTypingQuickScore = true
    }

    private func save() {
        if let editing {
            games.update(editing, to: draft)
        } else {
            games.add(draft)
        }
        dismiss()
    }

    private func choice(
        isSelected: Bool,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> some View
    ) -> some View {
        Button(action: action) {
            label()
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear), lineWidth: 2)
                )
                .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// The SF Symbols a custom Game can wear: the built-ins' own, and more
    /// for the tables they don't cover.
    private static let symbols = [
        "suit.heart.fill", "suit.club.fill", "suit.spade.fill", "suit.diamond.fill",
        "crown.fill", "square.grid.3x3.fill", "textformat.abc", "plusminus",
        "dice.fill", "die.face.5.fill", "star.fill", "trophy.fill",
        "flag.checkered", "target", "puzzlepiece.fill", "gamecontroller.fill",
        "bolt.fill", "flame.fill", "leaf.fill", "sparkles",
    ]
}

private extension Game.EndCondition {
    var target: Int? {
        if case .targetTotal(let target) = self { target } else { nil }
    }
}
