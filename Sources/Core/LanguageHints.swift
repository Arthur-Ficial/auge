import Foundation

/// Pure-logic parser for `--langs en-US,de-DE` style language hint strings.
public enum LanguageHints {
    /// Split a comma-separated language list, trim whitespace, drop empty entries.
    /// Returns BCP-47 tags in priority order.
    public static func parse(_ raw: String) -> [String] {
        raw.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
