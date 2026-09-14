import SwiftUI
import FinalScoreCore

/// The strip across the top of a Match: once ended, the Winner and a Rematch;
/// before that, the End condition's announcement once it is reached. Never in
/// the way of scoring, and nothing at all the rest of the time.
struct MatchBanner: View {
    let match: Match
    /// Asks to end the Match, from the announcement's End Match button.
    let onEnd: () -> Void
    /// Asks to set up a Rematch, once the Match is ended.
    let onRematch: () -> Void
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        if match.isEnded {
            HStack(spacing: 12) {
                Label(match.outcomeText ?? "Match ended", systemImage: "trophy.fill")
                    .font(.headline)
                    .foregroundStyle(.tint)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("outcome")
                Spacer(minLength: 8)
                Button("Rematch", systemImage: "arrow.counterclockwise", action: onRematch)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .accessibilityIdentifier("rematchButton")
            }
            .modifier(BannerStyle(isCompact: verticalSizeClass == .compact))
        } else if match.endConditionIsReached, let reason = match.endConditionText {
            HStack(spacing: 12) {
                Image(systemName: "flag.checkered")
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 0) {
                    Text(reason)
                        .font(.subheadline.bold())
                    if let standing = match.standingText {
                        Text(standing)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("endConditionNotice")
                Spacer(minLength: 8)
                Button("End Match", action: onEnd)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .accessibilityIdentifier("endMatchFromNotice")
            }
            .modifier(BannerStyle(isCompact: verticalSizeClass == .compact))
        }
    }
}

/// A full-width strip across the top of the Match, slimmer in landscape.
private struct BannerStyle: ViewModifier {
    let isCompact: Bool

    func body(content: Content) -> some View {
        content
            .padding(.horizontal)
            .padding(.vertical, isCompact ? 6 : 10)
            .background(.tint.opacity(0.12))
            .transition(.move(edge: .top).combined(with: .opacity))
    }
}
