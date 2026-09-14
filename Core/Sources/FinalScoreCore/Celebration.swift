extension Match {
    /// A moment worth marking with a little fanfare.
    public enum Celebration: Hashable, Sendable {
        /// The End condition was just reached, while the Match is still in play.
        case endConditionReached
        /// The Match was just ended, with this Winner or tie.
        case ended(Outcome)
    }

    /// What the change from `previous` to this Match earns: the moment the End
    /// condition is reached, or the moment the Match ends with a Winner or a
    /// tie. Only the change itself counts, so scoring on past the End
    /// condition, or correcting a Score once ended, celebrates nothing.
    public func celebration(since previous: Match) -> Celebration? {
        if isEnded {
            guard !previous.isEnded, let outcome else { return nil }
            return .ended(outcome)
        }
        return endConditionIsReached && !previous.endConditionIsReached ? .endConditionReached : nil
    }
}
