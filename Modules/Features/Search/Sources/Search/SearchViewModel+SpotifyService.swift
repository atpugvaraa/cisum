import Foundation
import Models
import Services

extension SearchViewModel {
    
    nonisolated func performFallbackMatch(
        title: String,
        artist: String,
        duration: TimeInterval?,
        candidates: [FederatedSearchItem]
    ) async -> SpotifyFallbackMatch? {
        return findBestSpotifyFallbackMatch(
            for: title,
            artist: artist,
            durationSeconds: duration,
            in: candidates
        )
    }

    struct SpotifyFallbackMatch {
        let item: FederatedSearchItem
        let score: Double
    }

    nonisolated func findBestSpotifyFallbackMatch(
        for title: String,
        artist: String,
        durationSeconds: TimeInterval?,
        in items: [FederatedSearchItem]
    ) -> SpotifyFallbackMatch? {
        let rankedMatches = items.compactMap { item -> SpotifyFallbackMatch? in
            let score = spotifyFallbackScore(
                sourceTitle: title,
                sourceArtist: artist,
                sourceDuration: durationSeconds,
                candidate: item
            )

            guard score >= 0.55 else { return nil }
            return SpotifyFallbackMatch(item: item, score: score)
        }

        return rankedMatches.max(by: { lhs, rhs in
            if lhs.score == rhs.score {
                return providerPriority(for: lhs.item.service) < providerPriority(for: rhs.item.service)
            }

            return lhs.score < rhs.score
        })
    }

    nonisolated private func spotifyFallbackScore(
        sourceTitle: String,
        sourceArtist: String,
        sourceDuration: TimeInterval?,
        candidate: FederatedSearchItem
    ) -> Double {
        let normalizedSourceTitle = normalizedRankingText(sourceTitle)
        let normalizedSourceArtist = normalizedRankingText(sourceArtist)
        let normalizedCandidateTitle = normalizedRankingText(candidate.title)
        let normalizedCandidateArtist = normalizedRankingText(primaryArtistName(from: candidate.subtitle))

        let titleOverlap = tokenOverlapScore(normalizedSourceTitle, normalizedCandidateTitle)
        let artistOverlap = tokenOverlapScore(normalizedSourceArtist, normalizedCandidateArtist)
        let titleContainsBonus = normalizedCandidateTitle.contains(normalizedSourceTitle) ? 0.16 : 0
        let sourceContainsBonus = normalizedSourceTitle.contains(normalizedCandidateTitle) ? 0.08 : 0
        let exactTitleBonus = normalizedSourceTitle == normalizedCandidateTitle ? 0.36 : 0
        let exactArtistBonus = normalizedSourceArtist == normalizedCandidateArtist ? 0.18 : 0
        let durationBonus = spotifyDurationMatchScore(
            sourceDuration: sourceDuration,
            candidateDuration: candidate.durationSeconds
        ) * 0.34
        let variantPenalty = spotifyVariantPenalty(
            sourceTitle: normalizedSourceTitle,
            candidateTitle: normalizedCandidateTitle
        )

        let providerBonus: Double
        switch candidate.service {
        case .youtubeMusic:
            providerBonus = 0.05
        case .youtube:
            providerBonus = 0.03
        case .spotify:
            providerBonus = 0
        }

        return (0.42 * titleOverlap)
            + (0.26 * artistOverlap)
            + titleContainsBonus
            + sourceContainsBonus
            + exactTitleBonus
            + exactArtistBonus
            + durationBonus
            + providerBonus
            + variantPenalty
    }

    nonisolated private func spotifyDurationMatchScore(sourceDuration: TimeInterval?, candidateDuration: TimeInterval?) -> Double {
        guard let sourceDuration, sourceDuration > 0 else { return 0.12 }
        guard let candidateDuration, candidateDuration > 0 else { return 0.12 }

        let delta = abs(sourceDuration - candidateDuration)
        let baseline = max(sourceDuration, candidateDuration, 1)
        let normalizedDelta = min(delta / baseline, 1)

        return max(0, 1 - (normalizedDelta * 3.5))
    }

    nonisolated private func spotifyVariantPenalty(sourceTitle: String, candidateTitle: String) -> Double {
        let sourceHasVariant = spotifyTitleHasVariantMarker(sourceTitle)
        let candidateHasVariant = spotifyTitleHasVariantMarker(candidateTitle)

        if candidateHasVariant && !sourceHasVariant {
            return -0.34
        }

        if sourceHasVariant && !candidateHasVariant {
            return -0.08
        }

        return 0
    }

    nonisolated private func spotifyTitleHasVariantMarker(_ title: String) -> Bool {
        let markers = [
            " remix",
            " live",
            " acoustic",
            " cover",
            " instrumental",
            " karaoke",
            " tribute",
            " mashup",
            " medley",
            " rework",
            " edit",
            " slowed",
            " sped up",
            " nightcore",
            " 8d",
            " mono",
            " remaster",
            " version"
        ]

        return markers.contains { title.contains($0) }
    }
}
