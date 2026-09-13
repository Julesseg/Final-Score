import SwiftUI
import FinalScoreCore

/// New Match: pick a Game, then pick its Players from the Roster.
struct NewMatchView: View {
    let roster: PlayerLibrary
    /// The most recent Match, whose Players come pre-picked.
    let previous: Match?
    let onStart: (Match) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(Game.builtIns, id: \.name) { game in
                NavigationLink {
                    PlayersView(game: game, roster: roster, previous: previous, onStart: onStart)
                } label: {
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
            .navigationTitle("Choose a Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("cancelNewMatchButton")
                }
            }
        }
    }
}

/// The Roster, with a tap to pick each Player into the next seat. Swiping a
/// Player renames or deletes them; + Add Player meets someone new inline.
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
        }
        .navigationTitle(setup.game.name)
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
