//
//  API Service.swift
//  cisum
//
//  Created by Aarav Gupta on 31/03/2024.
//

import Foundation

class APIService {
    private let baseUrl = "https://pipedapi.kavin.rocks/search"

    func fetchVideos(query: String, completion: @escaping ([APIVideo]) -> Void) {
        guard let url = buildURL(for: query) else {
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
                let videos = try self.decodeVideos(from: data)
                DispatchQueue.main.async {
                    completion(videos)
                }
            } catch {
                print("API JSON parsing error: \(error)")
                completion([])
            }
        }.resume()
    }

    private func buildURL(for query: String) -> URL? {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        let urlString = "\(baseUrl)?q=\(encodedQuery)&filter=music_songs"
        return URL(string: urlString)
    }

    private func decodeVideos(from data: Data) throws -> [APIVideo] {
        let searchResponse = try JSONDecoder().decode(APISearchResponse.self, from: data)
        return searchResponse.items.compactMap { item -> APIVideo? in
            guard let videoId = item.videoId else { return nil }
            return APIVideo(id: videoId, title: item.title, thumbnailURL: item.thumbnail)
        }
    }
}
