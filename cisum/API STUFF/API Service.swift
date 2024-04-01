//
//  API Service.swift
//  cisum
//
//  Created by Aarav Gupta on 31/03/2024.
//

import Foundation

class APIService {

    private let baseUrl = "https://pipedapi.kavin.rocks/search"

//    func fetchVideos(query: String, completion: @escaping ([YouTubeVideo]) -> Void) {
//        guard let url = URL(string: "\(baseUrl)?part=snippet&maxResults=25&q=\(query)&key=\(apiKey)") else { return }
//
//        URLSession.shared.dataTask(with: url) { data, response, error in
//            guard let data = data, error == nil else { return }
//
//            do {
//                let searchResponse = try JSONDecoder().decode(YouTubeSearchResponse.self, from: data)
//                let videos = searchResponse.items.compactMap { item -> YouTubeVideo? in
//                    guard let videoId = item.id.videoId else { return nil }
//                    return YouTubeVideo(id: videoId, title: item.snippet.title, description: item.snippet.description)
//                }
//                DispatchQueue.main.async {
//                    completion(videos)
//                }
//            } catch {
//                print(error)
//                completion([])
//            }
//        }.resume()
//    }
    
    func fetchVideos(query: String, completion: @escaping ([APIVideo]) -> Void) {
        // Construct the URL with conditional inclusion of the music category
        guard let url = URL(string: "\(baseUrl)?q=\(query)&filter=music_videos") else {
            print("Invalid URL")
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            // Check for errors or no data
            guard let data = data, error == nil else {
                print("API request error: \(error?.localizedDescription ?? "Unknown error")")
                completion([])
                return
            }
            
            do {
                // Decode the JSON response
                let searchResponse = try JSONDecoder().decode(APISearchResponse.self, from: data)
                // Map each item to a Video, filtering out any without a valid videoId
                let videos = searchResponse.items.compactMap { item -> APIVideo? in
                    guard let videoId = item.id.videoId else { return nil }
                    let thumbnailUrl = item.snippet.thumbnails.medium.url
                    // Since we don't have a separate audio URL, we pass nil for audioUrl
                    return APIVideo(title: item.snippet.title, uploader: "", thumbnailURL: "", audioStreams: "", videoStreams: "")
                }

                // Complete with the array of videos
                DispatchQueue.main.async {
                    completion(videos)
                }
            } catch {
                print("API JSON parsing error: \(error)")
                completion([])
            }
        }.resume()
    }
}
