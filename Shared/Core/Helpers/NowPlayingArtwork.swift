//
//  NowPlayingArtwork.swift
//  cisum
//
//  Created by GitHub Copilot.
//

import Foundation
import CryptoKit

nonisolated func normalizedITunesArtworkURL(from artworkURL: URL?) -> URL? {
    guard let artworkURL else { return nil }
    return normalizedITunesArtworkURL(from: artworkURL.absoluteString)
}

nonisolated func normalizedITunesArtworkURL(from artworkURLString: String?) -> URL? {
    guard let artworkURLString else { return nil }

    let decoded = artworkURLString.removingPercentEncoding ?? artworkURLString
    let candidates = [
        decoded.replacingOccurrences(of: "100x100", with: "1500x1500"),
        decoded.replacingOccurrences(of: "100bb", with: "1500bb"),
        decoded.replacingOccurrences(of: "%7Bw%7Dx%7Bh%7Dbb.%7Bf%7D", with: "1500x1500bb.jpg")
    ]

    for candidate in candidates {
        if let url = URL(string: candidate) {
            return url
        }
    }

    return URL(string: decoded)
}

nonisolated func normalizedMotionArtworkAlbumCacheKey(albumName: String?, artistName: String?) -> String? {
    guard let normalizedAlbum = normalizedMotionArtworkToken(albumName) else {
        return nil
    }

    if let normalizedArtist = normalizedMotionArtworkToken(artistName) {
        return "album::\(normalizedAlbum)::\(normalizedArtist)"
    }

    return "album::\(normalizedAlbum)"
}

nonisolated func motionArtworkCollectionCacheKey(collectionID: Int?) -> String? {
    guard let collectionID else {
        return nil
    }

    return "collection::\(collectionID)"
}

nonisolated func motionArtworkCatalogAlbumCacheKey(catalogAlbumID: String?) -> String? {
    guard let catalogAlbumID else {
        return nil
    }

    let trimmed = catalogAlbumID.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
        return nil
    }

    return "catalog-album::\(trimmed)"
}

nonisolated func motionArtworkVideoCacheID(mediaID: String, albumCacheKey: String?, sourceURL: URL) -> String {
    if let albumCacheKey,
       !albumCacheKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return "album-\(stableMotionArtworkHash(albumCacheKey))"
    }

    let fallbackSourceToken = stableMotionArtworkHash(sourceURL.absoluteString)
    return "media-\(mediaID)-\(fallbackSourceToken)"
}

nonisolated private func normalizedMotionArtworkToken(_ value: String?) -> String? {
    guard let value else { return nil }

    let lowered = value
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        .lowercased()

    guard !lowered.isEmpty else { return nil }

    let allowed = CharacterSet.alphanumerics
    let separated = lowered.unicodeScalars.map { scalar -> Character in
        if allowed.contains(scalar) {
            return Character(scalar)
        }

        return "-"
    }

    let collapsed = String(separated)
        .replacingOccurrences(of: "-{2,}", with: "-", options: .regularExpression)
        .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

    guard !collapsed.isEmpty else { return nil }
    return collapsed
}

nonisolated private func stableMotionArtworkHash(_ value: String) -> String {
    let digest = SHA256.hash(data: Data(value.utf8))
    return digest.prefix(12).map { String(format: "%02x", $0) }.joined()
}
