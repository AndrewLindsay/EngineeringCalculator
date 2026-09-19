import Foundation

enum EngineeringNumberFormatter {
    /// Formats engineering values for display. Very small/large magnitudes use
    /// scientific notation so significant digits are obvious and long runs of
    /// zeros are avoided.
    static func string(_ value: Double, significantDigits: Int = 4) -> String {
        guard value.isFinite else { return value.formatted() }
        if value == 0 { return "0" }

        let magnitude = abs(value)
        if magnitude < 0.001 || magnitude >= 1_000_000 {
            return scientific(value, significantDigits: significantDigits)
        }

        return value.formatted(
            .number
                .precision(.significantDigits(1...significantDigits))
                .grouping(.automatic)
        )
    }

    /// Uses a Unicode multiplication sign and superscript exponent, e.g.
    /// 8 × 10⁻⁷ rather than 0.0000008.
    private static func scientific(_ value: Double, significantDigits: Int) -> String {
        let exponent = Int(floor(log10(abs(value))))
        let coefficient = value / pow(10.0, Double(exponent))
        let coefficientText = coefficient.formatted(
            .number.precision(.significantDigits(1...significantDigits))
        )
        return "\(coefficientText) × 10\(superscript(exponent))"
    }

    private static func superscript(_ value: Int) -> String {
        let map: [Character: Character] = [
            "-": "⁻", "+": "⁺", "0": "⁰", "1": "¹", "2": "²",
            "3": "³", "4": "⁴", "5": "⁵", "6": "⁶", "7": "⁷",
            "8": "⁸", "9": "⁹"
        ]
        return String(String(value).compactMap { map[$0] })
    }

    /// Parses normal decimal or scientific-entry notation such as 8e-7 / 8E-7.
    static func parse(_ text: String) -> Double? {
        let cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "−", with: "-")
        guard !cleaned.isEmpty else { return nil }
        return Double(cleaned)
    }

    /// Suitable initial text for editable fields. Swift's Double representation
    /// naturally uses e-notation where appropriate and remains directly editable.
    static func editableString(_ value: Double?) -> String {
        guard let value else { return "" }
        return String(value)
    }
}