//
//  YouTubeService.swift
//  cisum
//
//  Created by Aarav Gupta on 26/03/2024.
//

import Foundation


class YouTubeService {
    private let apiKey = "AIzaSyAdsHV4dZy_N8az74YR8VX5j9lJeKzqlv4"
    private let baseUrl = "https://www.googleapis.com/youtube/v3/search"

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
    
    func fetchVideos(query: String, musicOnly: Bool = true, completion: @escaping ([YouTubeVideo]) -> Void) {
        let categoryPart = musicOnly ? "&videoCategoryId=10" : ""
        // Construct the URL with conditional inclusion of the music category
        guard let url = URL(string: "\(baseUrl)?part=snippet&maxResults=25&q=\(query)\(categoryPart)&type=video&key=\(apiKey)") else {
            print("Invalid URL")
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            // Check for errors or no data
            guard let data = data, error == nil else {
                print("YouTube API request error: \(error?.localizedDescription ?? "Unknown error")")
                completion([])
                return
            }
            
            do {
                // Decode the JSON response
                let searchResponse = try JSONDecoder().decode(YouTubeSearchResponse.self, from: data)
                // Map each item to a YouTubeVideo, filtering out any without a valid videoId
                let videos = searchResponse.items.compactMap { item -> YouTubeVideo? in
                    guard let videoId = item.id.videoId else { return nil }
                    let thumbnailUrl = item.snippet.thumbnails.medium.url
                    // Since we don't have a separate audio URL, we pass nil for audioUrl
                    return YouTubeVideo(id: videoId, title: item.snippet.title, thumbnailUrl: thumbnailUrl, audioUrl: nil)
                }

                // Complete with the array of videos
                DispatchQueue.main.async {
                    completion(videos)
                }
            } catch {
                print("YouTube API JSON parsing error: \(error)")
                completion([])
            }
        }.resume()
    }
}
