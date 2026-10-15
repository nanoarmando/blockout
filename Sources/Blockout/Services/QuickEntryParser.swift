import Foundation

struct QuickEntry: Equatable {
    var title: String
    var projectName: String?
    var estimateMinutes: Int?
    var urgency: Int
}

/// Parses the filter-and-create input: trailing `!`–`!!!` is urgency, a trailing `2h` or `1.5h` is the
/// estimate, and the longest existing project name found as a whole word or phrase is the project.
enum QuickEntryParser {
    static func parse(_ text: String, projectNames: [String]) -> QuickEntry {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var title = trimmed
        var urgency = 0
        var estimateMinutes: Int?

        if let match = title.firstMatch(of: /\s*(!{1,3})$/) {
            urgency = match.output.1.count
            title = String(title[..<match.range.lowerBound])
        }
        if let match = title.firstMatch(of: /\s+(\d+(?:\.\d+)?)h$/), let hours = Double(match.output.1) {
            estimateMinutes = Int((hours * 60).rounded())
            title = String(title[..<match.range.lowerBound])
        }
        if title.isEmpty { title = trimmed }

        return QuickEntry(
            title: title,
            projectName: detectProject(in: trimmed, projectNames: projectNames),
            estimateMinutes: estimateMinutes,
            urgency: urgency
        )
    }

    static func detectProject(in text: String, projectNames: [String]) -> String? {
        projectNames
            .sorted { $0.count > $1.count }
            .first { containsWholePhrase(text, $0) }
    }

    private static func containsWholePhrase(_ text: String, _ phrase: String) -> Bool {
        guard !phrase.isEmpty else { return false }
        var searchRange = text.startIndex..<text.endIndex
        while let range = text.range(of: phrase, options: .caseInsensitive, range: searchRange) {
            let before = range.lowerBound == text.startIndex ? nil : text[text.index(before: range.lowerBound)]
            let after = range.upperBound == text.endIndex ? nil : text[range.upperBound]
            if !isWordCharacter(before), !isWordCharacter(after) { return true }
            searchRange = text.index(after: range.lowerBound)..<text.endIndex
        }
        return false
    }

    private static func isWordCharacter(_ character: Character?) -> Bool {
        guard let character else { return false }
        return character.isLetter || character.isNumber
    }
}
