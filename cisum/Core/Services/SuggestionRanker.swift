import Foundation

struct SuggestionCandidate {
    let text: String
    let frequency: Int
    let successfulPlays: Int
    let recency: Date
    let sourceBoost: Double
}

enum SuggestionRanker {
    static func rank(input: String, candidates: [SuggestionCandidate], limit: Int = 8) -> [String] {
        let query = normalized(input)
        let now = Date()

        let ranked = candidates.map { candidate -> (String, Double) in
            let n = normalized(candidate.text)
            let jw = jaroWinkler(query, n)
            let freqScore = min(1.0, Double(candidate.frequency) / 20.0)
            let playScore = min(1.0, Double(candidate.successfulPlays) / 10.0)
            let ageHours = max(0.0, now.timeIntervalSince(candidate.recency) / 3600.0)
            let recencyScore = exp(-ageHours / 72.0)

            let total =
                (0.45 * jw) +
                (0.20 * recencyScore) +
                (0.20 * freqScore) +
                (0.10 * playScore) +
                (0.05 * candidate.sourceBoost)
            return (candidate.text, total)
        }

        return ranked
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }
            .uniquedPreservingOrder()
            .prefix(limit)
            .map { $0 }
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func jaroWinkler(_ s1: String, _ s2: String) -> Double {
        if s1 == s2 { return 1.0 }
        let a1 = Array(s1)
        let a2 = Array(s2)
        let l1 = a1.count
        let l2 = a2.count
        if l1 == 0 || l2 == 0 { return 0 }

        let matchDistance = max(l1, l2) / 2 - 1
        var a1Matches = Array(repeating: false, count: l1)
        var a2Matches = Array(repeating: false, count: l2)

        var matches = 0
        for i in 0..<l1 {
            let start = max(0, i - matchDistance)
            let end = min(i + matchDistance + 1, l2)
            for j in start..<end where !a2Matches[j] && a1[i] == a2[j] {
                a1Matches[i] = true
                a2Matches[j] = true
                matches += 1
                break
            }
        }

        if matches == 0 { return 0 }

        var t = 0
        var k = 0
        for i in 0..<l1 where a1Matches[i] {
            while !a2Matches[k] { k += 1 }
            if a1[i] != a2[k] { t += 1 }
            k += 1
        }

        let m = Double(matches)
        let jaro = (m / Double(l1) + m / Double(l2) + (m - Double(t) / 2.0) / m) / 3.0

        let prefix = commonPrefixLength(s1, s2, maxLength: 4)
        return jaro + Double(prefix) * 0.1 * (1.0 - jaro)
    }

    private static func commonPrefixLength(_ s1: String, _ s2: String, maxLength: Int) -> Int {
        let a1 = Array(s1)
        let a2 = Array(s2)
        let maxP = min(maxLength, min(a1.count, a2.count))
        var p = 0
        while p < maxP && a1[p] == a2[p] {
            p += 1
        }
        return p
    }
}

private extension Array where Element == String {
    func uniquedPreservingOrder() -> [String] {
        var seen = Set<String>()
        return self.filter { seen.insert($0.lowercased()).inserted }
    }
}
