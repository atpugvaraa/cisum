//
//  MusicMetadataNormalizer.swift
//  cisum
//
//  Created by GitHub Copilot on 29/03/26.
//

import Foundation
import YouTubeSDK

public nonisolated func normalizedMusicDisplayTitle(_ title: String, artist: String? = nil) -> String {
    let trimmedTitle = collapsedMusicWhitespace(title)
    guard !trimmedTitle.isEmpty else { return trimmedTitle }

    let strippedTitle = stripMusicNoiseSuffixes(from: trimmedTitle)
    let artistName = artist.map { normalizedMusicDisplayArtist($0, title: trimmedTitle) } ?? ""
    let dedupedTitle = artistName.isEmpty ? strippedTitle : stripDuplicateArtistText(from: strippedTitle, artist: artistName)
    return dedupedTitle.isEmpty ? trimmedTitle : dedupedTitle
}

public nonisolated func normalizedMusicDisplayArtist(_ artist: String, title: String? = nil) -> String {
    let trimmedArtist = collapsedMusicWhitespace(artist)
    guard !trimmedArtist.isEmpty else { return trimmedArtist }

    _ = title
    return stripArtistNoiseSuffixes(from: trimmedArtist)
}

public nonisolated func musicVideoSearchQuery(_ query: String) -> String {
    let trimmedQuery = collapsedMusicWhitespace(query)
    guard !trimmedQuery.isEmpty else { return trimmedQuery }

    if trimmedQuery.range(of: "official music video", options: .caseInsensitive) != nil {
        return trimmedQuery
    }

    return "\(trimmedQuery) (Official Music Video)"
}

public nonisolated func normalizedRankingText(_ value: String) -> String {
    let lowercased = value.lowercased()
    let withoutPunctuation = lowercased.replacingOccurrences(
        of: "[^a-z0-9\\s]",
        with: " ",
        options: .regularExpression
    )

    return withoutPunctuation
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

public nonisolated func tokenSet(from value: String) -> Set<String> {
    Set(normalizedRankingText(value).split(separator: " ").map(String.init))
}

public nonisolated func tokenOverlapScore(_ lhs: String, _ rhs: String) -> Double {
    let lhsTokens = tokenSet(from: lhs)
    let rhsTokens = tokenSet(from: rhs)

    guard !lhsTokens.isEmpty, !rhsTokens.isEmpty else { return 0 }

    let overlapCount = Double(lhsTokens.intersection(rhsTokens).count)
    let normalizer = Double(max(lhsTokens.count, rhsTokens.count))
    return normalizer == 0 ? 0 : overlapCount / normalizer
}

public nonisolated func normalizedArtworkURL(from rawValue: String?) -> URL? {
    guard var candidate = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines), !candidate.isEmpty else {
        return nil
    }

    if candidate.hasPrefix("//") {
        candidate = "https:" + candidate
    } else if !candidate.hasPrefix("http://") && !candidate.hasPrefix("https://") {
        candidate = "https://" + candidate
    }

    return URL(string: candidate)
}

nonisolated private func stripDuplicateArtistText(from title: String, artist: String) -> String {
    guard !title.isEmpty, !artist.isEmpty else { return title }

    let lowerTitle = title.lowercased()
    let lowerArtist = artist.lowercased()

    for separator in musicDisplaySeparators() {
        let lowerSeparator = separator.lowercased()
        let prefix = lowerArtist + lowerSeparator
        if lowerTitle.hasPrefix(prefix) {
            let startIndex = title.index(title.startIndex, offsetBy: artist.count + separator.count)
            return collapsedMusicWhitespace(String(title[startIndex...]))
        }

        let suffix = lowerSeparator + lowerArtist
        if lowerTitle.hasSuffix(suffix) {
            let endIndex = title.index(title.endIndex, offsetBy: -(artist.count + separator.count))
            return collapsedMusicWhitespace(String(title[..<endIndex]))
        }
    }

    for pair in [("(", ")"), ("[", "]"), ("{", "}")] {
        let suffix = " \(pair.0)\(artist)\(pair.1)"
        if lowerTitle.hasSuffix(suffix.lowercased()) {
            let endIndex = title.index(title.endIndex, offsetBy: -suffix.count)
            return collapsedMusicWhitespace(String(title[..<endIndex]))
        }
    }

    return title
}

nonisolated private func stripArtistNoiseSuffixes(from artist: String) -> String {
    stripTrailingNoise(in: artist, keywords: artistNoiseKeywords())
}

nonisolated private func stripMusicNoiseSuffixes(from title: String) -> String {
    stripTrailingNoise(in: title, keywords: musicNoiseKeywords())
}

nonisolated private func stripTrailingNoise(in value: String, keywords: [String]) -> String {
    var result = collapsedMusicWhitespace(value)

    while true {
        let updated = removeTrailingNoise(from: result, keywords: keywords)
        if updated == result {
            return updated
        }
        result = updated
    }
}

nonisolated private func removeTrailingNoise(from value: String, keywords: [String]) -> String {
    let separators = [" ", " - ", " – ", " — ", " | ", " • ", ": "]
    let bracketPairs = [("(", ")"), ("[", "]"), ("{", "}")]
    let lowerValue = value.lowercased()

    for keyword in keywords {
        let lowerKeyword = keyword.lowercased()

        for separator in separators {
            let candidate = (separator + keyword).lowercased()
            if lowerValue.hasSuffix(candidate) {
                let cutIndex = value.index(value.endIndex, offsetBy: -(separator.count + keyword.count))
                return collapsedMusicWhitespace(String(value[..<cutIndex]))
            }
        }

        for pair in bracketPairs {
            let candidate = " \(pair.0)\(keyword)\(pair.1)".lowercased()
            if lowerValue.hasSuffix(candidate) {
                let cutIndex = value.index(value.endIndex, offsetBy: -candidate.count)
                return collapsedMusicWhitespace(String(value[..<cutIndex]))
            }
        }

        if lowerValue.hasSuffix(lowerKeyword) {
            let cutIndex = value.index(value.endIndex, offsetBy: -keyword.count)
            return collapsedMusicWhitespace(String(value[..<cutIndex]))
        }
    }

    return value
}

nonisolated private func collapsedMusicWhitespace(_ value: String) -> String {
    value
        .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

nonisolated private func musicDisplaySeparators() -> [String] {
    [" - ", " – ", " — ", " | ", " • ", ": "]
}

nonisolated private func musicNoiseKeywords() -> [String] {
    [
        "official music video",
        "official audio",
        "lyric video",
        "lyrics",
        "live performance",
        "live",
        "performance",
        "topic",
        "visualizer",
        "audio",
        "music video",
        "mv",
        "provided to youtube by"
    ]
}

nonisolated private func artistNoiseKeywords() -> [String] {
    ["topic", "provided to youtube by"]
}

public nonisolated func resolvedMusicRegionCode() -> String {
    if let code = Locale.current.region?.identifier.trimmingCharacters(in: .whitespacesAndNewlines),
       code.count == 2 {
        return code.uppercased()
    }
    return "ZZ"
}

public nonisolated func resolvedInnerTubeRegionCode() -> String? {
    let region = resolvedMusicRegionCode()
    return region == "ZZ" ? nil : region
}

public nonisolated func resolvedInnerTubeLanguageCode() -> String {
    if #available(iOS 16.0, macOS 13.0, *) {
        if let code = Locale.current.language.languageCode?.identifier,
           !code.isEmpty {
            return code.lowercased()
        }
    }

    if let legacyCode = Locale.current.languageCode,
       !legacyCode.isEmpty {
        return legacyCode.lowercased()
    }

    return "en"
}

public nonisolated func shouldKeepMusicHomeItem(_ item: YouTubeItem) -> Bool {
    switch item {
    case .song:
        return true
    case .video(let video):
        return shouldKeepMusicVideoResult(video)
    case .channel(let channel):
        return shouldKeepMusicChannel(channel)
    case .playlist(let playlist):
        return shouldKeepMusicPlaylist(playlist)
    case .shelf(let shelf):
        return isLikelyMusicMetadata(title: shelf.title, secondaryText: nil)
    }
}

public nonisolated func shouldKeepMusicVideoResult(_ video: YouTubeVideo) -> Bool {
    isLikelyMusicMetadata(title: video.title, secondaryText: video.author)
}

public nonisolated func shouldKeepMusicChannel(_ channel: YouTubeChannel) -> Bool {
    isLikelyArtistChannelName(channel.title)
}

public nonisolated func shouldKeepMusicPlaylist(_ playlist: YouTubePlaylist) -> Bool {
    isLikelyMusicMetadata(title: playlist.title, secondaryText: playlist.author)
}

public nonisolated func isLikelyArtistChannelName(_ channelName: String) -> Bool {
    let normalizedName = collapsedMusicWhitespace(channelName).lowercased()
    guard !normalizedName.isEmpty else { return false }

    let positiveSignals = [
        "official artist channel",
        "- topic",
        "vevo",
        "records",
        "music",
        "band",
        "orchestra"
    ]

    let blockedSignals = [
        "gaming",
        "podcast",
        "reaction",
        "review",
        "tutorial",
        "vlog"
    ]

    if blockedSignals.contains(where: { normalizedName.contains($0) }) {
        return false
    }

    return positiveSignals.contains(where: { normalizedName.contains($0) })
}

public nonisolated func isLikelyMusicMetadata(title: String, secondaryText: String?) -> Bool {
    let normalizedTitle = collapsedMusicWhitespace(title).lowercased()
    let normalizedSecondary = collapsedMusicWhitespace(secondaryText ?? "").lowercased()
    let merged = "\(normalizedTitle) \(normalizedSecondary)"

    let blockedSignals = [
        "#shorts",
        "/shorts/",
        "shorts",
        "reaction",
        "review",
        "podcast",
        "interview",
        "tutorial",
        "gameplay",
        "gaming"
    ]

    if blockedSignals.contains(where: { merged.contains($0) }) {
        return false
    }

    let positiveSignals = [
        "official music video",
        "official video",
        "official audio",
        "lyric",
        "lyrics",
        "visualizer",
        "audio",
        "song",
        "single",
        "album",
        "remix",
        "acoustic",
        "feat.",
        "ft.",
        "vevo",
        "topic"
    ]

    if positiveSignals.contains(where: { merged.contains($0) }) {
        return true
    }

    return isLikelyArtistChannelName(secondaryText ?? "")
}
