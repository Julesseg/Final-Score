import SwiftUI
import FinalScoreCore

/// The strip across the top of a Match: once ended, the Winner and a Rematch;
/// before that, the End condition's announcement once it is reached. Never in
/// the way of scoring, and nothing at all the rest of the time. Its symbol
/// jumps the moment what it announces happens.
struct MatchBanner: View {
    let match: Match
    /// Asks to end the Match, from the announcement's End Match button.
    let onEnd: () -> Void
    /// Asks to set up a Rematch, once the Match is ended.
    let onRematch: () -> Void
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.celebrationMoment) private var moment

    var body: some View {
        if match.isEnded {
            HStack(spacing: 12) {
                Label {
                    Text(match.outcomeText ?? "Match ended")
                } icon: {
                    Image(systemName: "trophy.fill")
                        .symbolEffect(.bounce.up, options: .repeat(2), value: jump)
                }
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
            .modifier(BannerStyle(isCompact: verticalSizeClass == .compact, reduceMotion: reduceMotion))
        } else if match.endConditionIsReached, let reason = match.endConditionText {
            HStack(spacing: 12) {
                Image(systemName: "flag.checkered")
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .symbolEffect(.wiggle, options: .repeat(2), value: jump)
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
            .modifier(BannerStyle(isCompact: verticalSizeClass == .compact, reduceMotion: reduceMotion))
        }
    }

    /// Changes as a Celebration happens, and never under Reduce Motion.
    private var jump: UUID? {
        reduceMotion ? nil : moment?.id
    }
}

/// A full-width strip across the top of the Match, slimmer in landscape. It
/// drops in from the top, or fades in under Reduce Motion.
private struct BannerStyle: ViewModifier {
    let isCompact: Bool
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .padding(.horizontal)
            .padding(.vertical, isCompact ? 6 : 10)
            .background(.tint.opacity(0.12))
            .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
    }
}
