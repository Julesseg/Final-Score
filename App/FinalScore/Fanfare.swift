import SwiftUI
import FinalScoreCore

/// A Celebration as it happens, stamped so that the same one twice running
/// still fires twice.
struct CelebrationMoment: Equatable {
    let celebration: Match.Celebration
    let id = UUID()
}

extension EnvironmentValues {
    /// The Celebration that just happened over the Match on screen, if any.
    @Entry var celebrationMoment: CelebrationMoment?
}

extension View {
    /// Digits that roll and a springy bump each time `value` changes, as a
    /// Score lands. A plain fade under Reduce Motion.
    func scoreBump(on value: Int?) -> some View {
        modifier(ScoreBump(value: value))
    }

    /// Everything that makes a Match feel alive: a tap as each Score lands, the
    /// banner springing in, and a Celebration's haptic and confetti the moment
    /// it happens. The moment is handed down for `MatchBanner` to mark too.
    func celebrating(_ match: Match) -> some View {
        modifier(Celebrating(match: match))
    }
}

private struct ScoreBump: ViewModifier {
    let value: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .contentTransition(reduceMotion ? .opacity : .numericText(value: Double(value ?? 0)))
            .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.35, bounce: 0.3), value: value)
            .keyframeAnimator(initialValue: 1.0, trigger: value) { content, scale in
                content.scaleEffect(scale)
            } keyframes: { _ in
                SpringKeyframe(reduceMotion ? 1 : 1.15, duration: 0.1, spring: .snappy)
                SpringKeyframe(1, duration: 0.45, spring: .bouncy(extraBounce: 0.15))
            }
    }
}

private struct Celebrating: ViewModifier {
    let match: Match
    @State private var moment: CelebrationMoment?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let bannerAnimation: Animation = reduceMotion ? .default : .spring(duration: 0.45, bounce: 0.3)
        content
            .environment(\.celebrationMoment, moment)
            .animation(bannerAnimation, value: match.endConditionIsReached)
            .animation(bannerAnimation, value: match.isEnded)
            // Each key lands its Score, so each key taps; taking a Score or a
            // Round away doesn't.
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.7), trigger: scores) { old, new in
                new.count >= old.count
            }
            .sensoryFeedback(trigger: moment) { _, moment in
                moment.map { Fanfare($0.celebration, in: match).feedback }
            }
            .overlay {
                if let moment, !reduceMotion {
                    let fanfare = Fanfare(moment.celebration, in: match)
                    ConfettiBurst(colors: fanfare.colors, pieces: fanfare.pieces)
                        .id(moment.id)
                }
            }
            .onChange(of: match) { previous, updated in
                if let celebration = updated.celebration(since: previous) {
                    moment = CelebrationMoment(celebration: celebration)
                }
            }
    }

    /// Every Score in the Match, whichever its Structure.
    private var scores: [Score] {
        match.rounds.flatMap(\.scores) + match.tallyScores
    }
}

/// How a Celebration is marked: a full burst in the Winner's colours once the
/// Match ends, a smaller one in every Team's colours for the announcement,
/// which comes mid-Match.
private struct Fanfare {
    let feedback: SensoryFeedback
    let colors: [Color]
    let pieces: Int

    init(_ celebration: Match.Celebration, in match: Match) {
        let teams: [Team]
        switch celebration {
        case .endConditionReached:
            (feedback, teams, pieces) = (.impact(weight: .heavy), match.teams, 20)
        case .ended(.won(let winner)):
            (feedback, teams, pieces) = (.success, [winner], 40)
        case .ended(.tied(let tied)):
            (feedback, teams, pieces) = (.success, tied, 40)
        }
        colors = teams.map { match.accent(of: $0.id).color } + [match.game.accent.color]
    }
}

/// Confetti thrown up across the Match that falls away in under two seconds.
/// Never in the way of a tap, and invisible to VoiceOver.
private struct ConfettiBurst: View {
    let colors: [Color]
    let pieces: Int
    @State private var start = Date()
    @State private var isDone = false

    private nonisolated static let duration: TimeInterval = 1.8

    var body: some View {
        let confetti = (0..<pieces).map { Piece(seed: $0, colorCount: colors.count) }
        TimelineView(.animation(paused: isDone)) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSince(start)
                guard elapsed < Self.duration else { return }
                for piece in confetti {
                    piece.draw(in: &context, size: size, elapsed: elapsed, color: colors[piece.colorIndex])
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            try? await Task.sleep(for: .seconds(Self.duration))
            isDone = true
        }
    }

    /// One scrap of confetti. Its flight is drawn from its seed, so every frame
    /// agrees on where it is.
    private struct Piece {
        let colorIndex: Int
        let originX: Double
        let velocity: CGVector
        let spin: Double
        let size: CGSize

        init(seed: Int, colorCount: Int) {
            var generator = SeededGenerator(seed: UInt64(seed) &+ 1)
            colorIndex = Int.random(in: 0..<max(colorCount, 1), using: &generator)
            originX = Double.random(in: 0.1...0.9, using: &generator)
            velocity = CGVector(
                dx: Double.random(in: -160...160, using: &generator),
                dy: Double.random(in: -520 ... -220, using: &generator)
            )
            spin = Double.random(in: -12...12, using: &generator)
            size = CGSize(width: Double.random(in: 6...10, using: &generator), height: Double.random(in: 10...16, using: &generator))
        }

        func draw(in context: inout GraphicsContext, size canvas: CGSize, elapsed t: Double, color: Color) {
            let gravity = 900.0
            let x = originX * canvas.width + velocity.dx * t
            let y = canvas.height * 0.3 + velocity.dy * t + gravity * t * t / 2
            let fade = max(0, 1 - t / ConfettiBurst.duration)
            var piece = context
            piece.opacity = fade
            piece.translateBy(x: x, y: y)
            piece.rotate(by: .radians(spin * t))
            // Squashed as it turns over, like paper.
            piece.scaleBy(x: 1, y: cos(spin * t / 2))
            piece.fill(
                Path(roundedRect: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height), cornerRadius: 2),
                with: .color(color)
            )
        }
    }
}

/// SplitMix64: the same seed gives the same confetti on every frame.
private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
