// PROTOTYPE — throwaway, on branch prototype/new-round-row only. Never merge.
// Question: how should the scorepad's New Round row look so it feels fuller
// than a lone + in a grey cell? Four variants of the row's label, switched in
// DEBUG by the floating bar at the bottom of the scorepad, or at launch with
// `-prototype.newRoundVariant B`.

import SwiftUI
import FinalScoreCore

enum NewRoundVariant: String, CaseIterable {
    case a = "A", b = "B", c = "C", d = "D"

    var name: String {
        switch self {
        case .a: "Lone + (PR #41)"
        case .b: "Labelled cell"
        case .c: "Ghost Round"
        case .d: "Tinted, with Dealer"
        }
    }
}

/// Everything a variant may show about the Round the row would add.
struct NextRoundInfo {
    let number: Int
    let dealer: String?
    let teamCount: Int
    let roundColumnWidth: CGFloat
    let columnWidth: CGFloat
    let visibleWidth: CGFloat

    init(match: Match, roundColumnWidth: CGFloat, columnWidth: CGFloat, visibleWidth: CGFloat) {
        number = match.rounds.count + 1
        let dealerID = match.rounds.last?.dealer.flatMap { match.seating?.dealer(after: $0) }
        dealer = match.players.first { $0.id == dealerID }?.name
        teamCount = match.teams.count
        self.roundColumnWidth = roundColumnWidth
        self.columnWidth = columnWidth
        self.visibleWidth = visibleWidth
    }
}

struct NewRoundRowPrototypeLabel: View {
    let variant: NewRoundVariant
    let info: NextRoundInfo

    var body: some View {
        switch variant {
        case .a: loneCell
        case .b: labelledCell
        case .c: ghostRound
        case .d: tintedWithDealer
        }
    }

    /// A: what PR #41 ships today.
    private var loneCell: some View {
        Image(systemName: "plus")
            .font(.title3.weight(.semibold))
            .foregroundStyle(.tint)
            .frame(width: max(info.visibleWidth - 6, 0), height: 44)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(.fill.tertiary))
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 3)
    }

    /// B: the same grey cell, but it says what it does and which Round it adds.
    private var labelledCell: some View {
        Label("Round \(info.number)", systemImage: "plus")
            .font(.headline)
            .foregroundStyle(.tint)
            .frame(width: max(info.visibleWidth - 6, 0), height: 44)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(.fill.tertiary))
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 3)
    }

    /// C: the next Round drawn in outline, in the grid's own columns: its
    /// number, and one dashed empty cell per Team waiting to be scored.
    private var ghostRound: some View {
        HStack(spacing: 0) {
            Image(systemName: "plus")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.tint)
                .frame(width: info.roundColumnWidth)
            ForEach(0..<info.teamCount, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.tint.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .background(RoundedRectangle(cornerRadius: 8).fill(.tint.opacity(0.05)))
                    .overlay {
                        Text("\(info.number)")
                            .font(.title3.monospacedDigit())
                            .foregroundStyle(.tint.opacity(0.5))
                    }
                    .frame(height: 44)
                    .padding(.horizontal, 3)
                    .frame(width: info.columnWidth)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// D: a prominent tinted button, like a selected Score, that also says who
    /// deals the Round it starts.
    private var tintedWithDealer: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
            VStack(alignment: .leading, spacing: 0) {
                Text("New Round")
                    .font(.headline)
                Text(info.dealer.map { "Round \(info.number) · \($0) deals" } ?? "Round \(info.number)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.tint)
        .frame(width: max(info.visibleWidth - 6, 0), height: 56)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12).fill(.tint.opacity(0.12))
            RoundedRectangle(cornerRadius: 12).strokeBorder(.tint.opacity(0.6), lineWidth: 1.5)
        }
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 3)
    }
}

/// Floating ◀ variant ▶ bar, visibly not part of the design.
struct NewRoundVariantSwitcher: View {
    @Binding var variant: NewRoundVariant

    var body: some View {
        HStack(spacing: 14) {
            Button { step(-1) } label: { Image(systemName: "chevron.left") }
                .accessibilityIdentifier("prototype.previous")
            Text("\(variant.rawValue) · \(variant.name)")
                .font(.footnote.monospaced().bold())
                .accessibilityIdentifier("prototype.variant")
            Button { step(1) } label: { Image(systemName: "chevron.right") }
                .accessibilityIdentifier("prototype.next")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Capsule().fill(.black.opacity(0.85)))
        .shadow(radius: 6)
        .padding(.bottom, 8)
    }

    private func step(_ delta: Int) {
        let all = NewRoundVariant.allCases
        let index = all.firstIndex(of: variant)! + delta
        variant = all[(index + all.count) % all.count]
    }
}
