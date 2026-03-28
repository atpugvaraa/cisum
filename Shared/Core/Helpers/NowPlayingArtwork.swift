//
//  NowPlayingArtwork.swift
//  cisum
//
//  Created by GitHub Copilot.
//

import Foundation

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
