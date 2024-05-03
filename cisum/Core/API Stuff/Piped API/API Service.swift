//
//  API Service.swift
//  cisum
//
//  Created by Aarav Gupta on 31/03/2024.
//

import Foundation

class APIService {
    private let baseUrl = "https://pipedapi.kavin.rocks/search"

    enum MediaType: String {
        case songs = "music_songs"
        case videos = "music_videos"
        case artists = "music_artists"
    }

    func fetchMedia(query: String, mediaType: MediaType, completion: @escaping ([VideoResponse]) -> Void) {
        guard let url = buildURL(for: query, filter: mediaType.rawValue) else {
            print("Invalid URL")
            completion([])
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                print("API request error: \(error?.localizedDescription ?? "Unknown error")")
                completion([])
                return
            }

            do {
                let videos = try self.decodeMedia(from: data, mediaType: mediaType)
                DispatchQueue.main.async {
                    completion(videos)
                }
            } catch {
                print("API JSON parsing error: \(error)")
                completion([])
            }
        }.resume()
    }

    private func buildURL(for query: String, filter: String) -> URL? {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            print("Failed to encode query")
            return nil
        }
        let urlString = "\(baseUrl)?q=\(encodedQuery)&filter=\(filter)"
        return URL(string: urlString)
    }

    private func decodeMedia(from data: Data, mediaType: MediaType) throws -> [VideoResponse] {
        if mediaType == .songs {
            let songSearchResponse = try JSONDecoder().decode(SongSearchResponse.self, from: data)
            return songSearchResponse.items.compactMap { item -> VideoResponse? in
                guard let videoId = item.videoId else { return nil }
                return VideoResponse(id: videoId, title: item.title, artistName: item.artistName, thumbnailURL: item.thumbnailURL, duration: item.duration)
            }
        } else if mediaType == .videos {
            let videoSearchResponse = try JSONDecoder().decode(VideoSearchResponse.self, from: data)
            return videoSearchResponse.items.compactMap { item -> VideoResponse? in
                guard let videoId = item.videoId else { return nil }
                return VideoResponse(id: videoId, title: item.title, artistName: item.artistName, thumbnailURL: item.thumbnailURL, duration: item.duration)
            }
        }
        return []
    }

    func fetchArtists(query: String, mediaType: MediaType, completion: @escaping ([ArtistResponse]) -> Void) {
        guard let url = artistURL(for: query, filter: MediaType.artists.rawValue) else {
            print("Invalid URL")
            completion([])
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                print("API request error: \(error?.localizedDescription ?? "Unknown error")")
                completion([])
                return
            }

            do {
                let artists = try self.decodeArtists(from: data)
                DispatchQueue.main.async {
                    completion(artists)
                }
            } catch {
                print("API JSON parsing error: \(error)")
                completion([])
            }
        }.resume()
    }

    private func artistURL(for query: String, filter: String) -> URL? {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            print("Failed to encode query")
            return nil
        }
        let urlString = "\(baseUrl)?q=\(encodedQuery)&filter=\(filter)"
        return URL(string: urlString)
    }

    private func decodeArtists(from data: Data) throws -> [ArtistResponse] {
        let searchResponse = try JSONDecoder().decode(ArtistSearchResponse.self, from: data)
        return searchResponse.items.compactMap { item -> ArtistResponse? in
            return ArtistResponse(id: item.artistId, name: item.name, avatarURL: item.thumbnail)
        }
    }
}
