import Foundation

/// Pure-logic merger that flattens multiple OCR passes into a single line list,
/// preserving first-seen order and dropping exact duplicates.
///
/// Used by the multi-pass OCR path: Vision's recognizer biases to the first
/// listed language and skips other scripts, so when `--langs` has more than
/// one entry, auge runs OCR once per language and merges with this helper.
public enum LineMerger {
    /// Merge multiple OCR runs into a single list. The first occurrence of
    /// each unique line wins; later duplicates are dropped.
    public static func merge(_ runs: [[String]]) -> [String] {
        var seen = Set<String>()
        var merged: [String] = []
        for run in runs {
            for line in run {
                if seen.insert(line).inserted {
                    merged.append(line)
                }
            }
        }
        return merged
    }
}
