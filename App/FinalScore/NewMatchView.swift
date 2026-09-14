import SwiftUI
import FinalScoreCore

/// New Match: pick a Game, then pick its Players from the Roster. The custom
/// Games are listed below the built-ins, and authored from here too.
struct NewMatchView: View {
    let roster: PlayerLibrary
    let games: GameLibrary
    /// The most recent Match, whose Players come pre-picked.
    let previous: Match?
    let onStart: (Match) -> Void
    /// The Game picked, once past the list of Games.
    @State private var path: [Game]
    @State private var gameForm: GameFormRequest?
    @Environment(\.dismiss) private var dismiss

    /// Opens on the `game`'s Players when it is already chosen, with the list
    /// of Games still one step back.
    init(
        roster: PlayerLibrary,
        games: GameLibrary,
        previous: Match?,
        game: Game? = nil,
        onStart: @escaping (Match) -> Void
    ) {
        self.roster = roster
        self.games = games
        self.previous = previous
        self.onStart = onStart
        _path = State(initialValue: game.map { [$0] } ?? [])
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    ForEach(Game.builtIns, id: \.name) { game in
                        row(for: game)
                            // Built-ins are read-only: editing one starts from a copy.
                            .contextMenu {
                                Button("Duplicate & Edit", systemImage: "plus.square.on.square") {
                                    gameForm = GameFormRequest(draft: games.duplicate(game), editing: nil)
                                }
                                .accessibilityIdentifier("duplicateGameButton")
                            }
                    }
                }

                if !games.customGames.isEmpty {
                    Section("Your Games") {
                        ForEach(games.customGames) { custom in
                            row(for: custom.game)
                                // No full swipe, as on the Roster: a stray
                                // swipe shouldn't delete a Game.
                                .swipeActions(allowsFullSwipe: false) {
                                    Button("Delete", systemImage: "trash", role: .destructive) {
                                        games.delete(custom.id)
                                    }
                                    Button("Edit", systemImage: "pencil") {
                                        gameForm = GameFormRequest(draft: GameDraft(game: custom.game), editing: custom.id)
                                    }
                                    .tint(.orange)
                                }
                        }
                    }
                }

                Section {
                    Button("Create Game", systemImage: "plus") {
                        gameForm = GameFormRequest(draft: GameDraft(), editing: nil)
                    }
                    .accessibilityIdentifier("createGameButton")
                } footer: {
                    Text("Long-press a built-in Game to make an editable copy of it.")
                }
            }
            .navigationTitle("Choose a Game")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Game.self) { game in
                PlayersView(game: game, roster: roster, previous: previous, onStart: onStart)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("cancelNewMatchButton")
                }
            }
            .sheet(item: $gameForm) { request in
                GameFormView(games: games, request: request)
            }
        }
    }

    private func row(for game: Game) -> some View {
        NavigationLink(value: game) {
            HStack(spacing: 12) {
                GameSymbol(game: game)
                VStack(alignment: .leading, spacing: 2) {
                    Text(game.name)
                        .font(.headline)
                    Text(game.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityIdentifier("game.\(game.name)")
    }
}

/// The Roster, with a tap to pick each Player into the next seat. Swiping a
/// Player renames or deletes them; + Add Player meets someone new inline. A
/// Game that tracks the Dealer also asks which way the deal passes, and a Team
/// Game shows the Teams its seats compose, editable before Start.
private struct PlayersView: View {
    let roster: PlayerLibrary
    let onStart: (Match) -> Void
    @State private var setup: MatchSetup
    @State private var isAddingPlayer: Bool
    @State private var newPlayerName = ""
    @FocusState private var isNamingNewPlayer: Bool
    @State private var renaming: Player?
    @State private var newName = ""

    init(game: Game, roster: PlayerLibrary, previous: Match?, onStart: @escaping (Match) -> Void) {
        self.roster = roster
        self.onStart = onStart
        _setup = State(initialValue: MatchSetup(game: game, roster: roster.players, previous: previous))
        // With nobody on the Roster yet, there is nothing to do but add someone.
        _isAddingPlayer = State(initialValue: roster.players.isEmpty)
    }

    var body: some View {
        Form {
            Section {
                ForEach(roster.players) { player in
                    row(for: player)
                }

                if isAddingPlayer {
                    TextField("Name", text: $newPlayerName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .focused($isNamingNewPlayer)
                        .submitLabel(.done)
                        .onSubmit(addPlayer)
                        .accessibilityIdentifier("newPlayerName")
                } else {
                    Button("Add Player", systemImage: "plus") {
                        isAddingPlayer = true
                        isNamingNewPlayer = true
                    }
                    .accessibilityIdentifier("addPlayerButton")
                }
            } header: {
                Text("Players")
            } footer: {
                Text(setup.game.summary)
            }

            if setup.game.teamPlay != .individual {
                Section {
                    ForEach(Array(setup.teams.enumerated()), id: \.offset) { index, players in
                        teamRow(index, players: players)
                    }
                } header: {
                    Text("Teams")
                } footer: {
                    Text(teamsFooter)
                }
            }

            if setup.game.tracksDealer {
                Section {
                    Picker("Deal passes", selection: $setup.rotation) {
                        Text("Clockwise").tag(Seating.Rotation.clockwise)
                        Text("Counter-clockwise").tag(Seating.Rotation.counterclockwise)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("rotationPicker")
                } header: {
                    Text("Dealer")
                } footer: {
                    Text("Pick Players in the order they sit, going clockwise. Seat 1 deals first, then the deal passes one seat each Round.")
                }
            }
        }
        .navigationTitle(setup.game.name)
        .tint(setup.game.accent.color)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Start") {
                    setup.makeMatch().map(onStart)
                }
                .disabled(!setup.canStart)
                .accessibilityIdentifier("startMatchButton")
            }
        }
        .onChange(of: roster.players) { _, players in
            setup.roster = players
        }
        .onAppear {
            isNamingNewPlayer = isAddingPlayer
        }
        .alert("Rename Player", isPresented: isRenaming, presenting: renaming) { player in
            TextField("Name", text: $newName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .accessibilityIdentifier("renamePlayerName")
            Button("Cancel", role: .cancel) {}
            Button("Rename") { roster.rename(player, to: newName) }
                .disabled(!roster.canRename(player, to: newName))
                .accessibilityIdentifier("confirmRenameButton")
        }
    }

    /// One Team and its Players, each a menu that trades them with another
    /// seat — which is how a Team is changed, since who plays with whom follows
    /// from where people sit.
    private func teamRow(_ index: Int, players: [Player]) -> some View {
        HStack(spacing: 8) {
            Text("Team \(index + 1)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            ForEach(Array(players.enumerated()), id: \.element.id) { slot, player in
                swapMenu(for: player, identifier: "teamSeat.\(index).\(slot)")
            }
        }
    }

    private func swapMenu(for player: Player, identifier: String) -> some View {
        Menu {
            ForEach(setup.swapCandidates(for: player.id)) { other in
                Button("Swap with \(other.name)") {
                    setup.swapSeats(player.id, other.id)
                }
            }
        } label: {
            Text(player.name)
                .lineLimit(1)
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(player.name)
        .accessibilityHint("Swaps seats to change the Teams")
    }

    /// How to finish composing the Teams, or how to re-form the ones composed.
    private var teamsFooter: String {
        let swapping = "Seats alternate between Teams, so partners sit across the table. Tap a Player to swap seats and change the Teams."
        guard !setup.canStart else { return swapping }
        return "Every Team needs \(setup.game.teamPlay.size) Players before the Match can start. " + swapping
    }

    private func row(for player: Player) -> some View {
        let seat = setup.seat(of: player.id)
        return Button {
            setup.toggle(player.id)
        } label: {
            HStack {
                Text(player.name)
                    .foregroundStyle(setup.canPick(player.id) ? .primary : .secondary)
                Spacer()
                // The seat number, so the Seating order is visible as it's picked.
                Image(systemName: seat.map { "\($0).circle.fill" } ?? "circle")
                    .font(.title2)
                    .foregroundStyle(seat == nil ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.tint))
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        // No full swipe: on a list tapped to pick Players, a stray swipe
        // shouldn't delete one.
        .swipeActions(allowsFullSwipe: false) {
            Button("Delete", systemImage: "trash", role: .destructive) { roster.delete(player) }
            Button("Rename", systemImage: "pencil") {
                newName = player.name
                renaming = player
            }
            .tint(.orange)
        }
        .accessibilityIdentifier("player.\(player.name)")
        .accessibilityValue(seat.map { "Seat \($0)" } ?? "")
        .accessibilityAddTraits(seat == nil ? [] : .isSelected)
    }

    /// Adds the name typed and picks that Player, then stays open for the next
    /// name. Submitting it blank puts the field away.
    private func addPlayer() {
        guard let player = roster.add(named: newPlayerName) else {
            isAddingPlayer = false
            return
        }
        // Handed over now rather than left to `onChange`, which runs too late
        // for `pick` to find the new Player on the Roster.
        setup.roster = roster.players
        setup.pick(player.id)
        newPlayerName = ""
        isNamingNewPlayer = true
    }

    private var isRenaming: Binding<Bool> {
        Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })
    }
}
