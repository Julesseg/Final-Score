import Foundation

/// A Score being typed on the keypad. Opening on a Team that already has a
/// Score shows it; the first digit typed replaces it, while delete and the
/// sign key edit it in place.
public struct Override: Equatable, Sendable {
    private var digits: String
    private var isNegative: Bool
    private var replacesOnType: Bool

    private static let maxDigits = 6

    /// An Override over an existing Score's `points`, or over no Score yet.
    public init(points: Int? = nil) {
        digits = points.map { String($0.magnitude) } ?? ""
        isNegative = (points ?? 0) < 0
        replacesOnType = points != nil
    }

    public var points: Int {
        let magnitude = Int(digits) ?? 0
        return isNegative ? -magnitude : magnitude
    }

    public var text: String {
        (isNegative ? "-" : "") + (digits.isEmpty ? "0" : digits)
    }

    public mutating func type(_ digit: Int) {
        if replacesOnType {
            digits = ""
            isNegative = false
            replacesOnType = false
        }
        guard digits.count < Self.maxDigits else { return }
        digits = digits == "0" ? String(digit) : digits + String(digit)
    }

    public mutating func deleteBackward() {
        replacesOnType = false
        if !digits.isEmpty {
            digits.removeLast()
        }
    }

    public mutating func toggleSign() {
        replacesOnType = false
        isNegative.toggle()
    }
}
