import SwiftUI
import FinalScoreCore

/// New Match: pick a Game, then name the Players.
struct NewMatchView: View {
    let onStart: (Match) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(Game.builtIns, id: \.name) { game in
                NavigationLink {
                    PlayersView(game: game, onStart: onStart)
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
                }
            }
        }
    }
}

private struct PlayersView: View {
    let onStart: (Match) -> Void
    @State private var setup: MatchSetup
    @FocusState private var focusedPlayer: Int?

    init(game: Game, onStart: @escaping (Match) -> Void) {
        self.onStart = onStart
        _setup = State(initialValue: MatchSetup(game: game))
    }

    var body: some View {
        Form {
            Section {
                ForEach(setup.playerNames.indices, id: \.self) { index in
                    TextField("Player \(index + 1)", text: name(at: index))
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .focused($focusedPlayer, equals: index)
                        .submitLabel(index == setup.playerNames.count - 1 ? .done : .next)
                        .onSubmit { focusedPlayer = index + 1 < setup.playerNames.count ? index + 1 : nil }
                        .accessibilityIdentifier("playerName.\(index)")
                }
                .onDelete { offsets in
                    offsets.first.map { setup.removePlayer(at: $0) }
                }
                .deleteDisabled(!setup.canRemovePlayer)

                if setup.canAddPlayer {
                    Button("Add Player", systemImage: "plus") {
                        setup.addPlayer()
                        focusedPlayer = setup.playerNames.count - 1
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
        .onAppear { focusedPlayer = 0 }
    }

    /// Bounds-checked, so a row animating out after a delete can't read past the end.
    private func name(at index: Int) -> Binding<String> {
        Binding(
            get: { setup.playerNames.indices.contains(index) ? setup.playerNames[index] : "" },
            set: { if setup.playerNames.indices.contains(index) { setup.playerNames[index] = $0 } }
        )
    }
}
