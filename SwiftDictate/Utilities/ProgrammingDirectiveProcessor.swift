import Foundation

enum ProgrammingDirectiveProcessor {
    private static let boundaryWords = [
        "before", "after", "then", "and", "to", "for", "in", "on", "with",
        "from", "into", "as", "when", "while", "where", "which", "that",
    ]

    private static let literalDiscussionWords: Set<String> = [
        "is", "are", "was", "were", "means", "refers", "describes", "for",
    ]

    private static var expression: NSRegularExpression {
        let boundaries = boundaryWords.joined(separator: "|")
        let pattern = #"\b(camel|snake)\s+case\s+([[:alnum:]]+(?:\s+[[:alnum:]]+)*?)(?=\s+(?:"#
            + boundaries
            + #")\b|[,.;:!?]|$)"#
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }

    static func process(_ text: String) -> String {
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = expression.matches(in: text, range: fullRange)
        var result = text

        for match in matches.reversed() {
            guard let matchRange = Range(match.range, in: result),
                  let styleRange = Range(match.range(at: 1), in: result),
                  let wordsRange = Range(match.range(at: 2), in: result) else {
                continue
            }

            let words = result[wordsRange].split(whereSeparator: { $0.isWhitespace }).map(String.init)
            guard let firstWord = words.first,
                  !literalDiscussionWords.contains(firstWord.lowercased()) else {
                continue
            }

            let identifier: String
            if result[styleRange].lowercased() == "snake" {
                identifier = words.map { $0.lowercased() }.joined(separator: "_")
            } else {
                identifier = lowerCamelCase(words)
            }

            result.replaceSubrange(matchRange, with: identifier)
        }

        return result
    }

    private static func lowerCamelCase(_ words: [String]) -> String {
        guard let first = words.first else { return "" }
        return first.lowercased() + words.dropFirst().map {
            let lowercased = $0.lowercased()
            return lowercased.prefix(1).uppercased() + lowercased.dropFirst()
        }.joined()
    }
}
