////
////  PipedAPIService.swift
////  cisum
////
////  Created by Aarav Gupta on 01/04/24.
////
//
//import SwiftUI
//import Foundation
//
//class PipedAPIService {
//    private let baseUrl = "https://pipedapi.kavin.rocks/results"
//    
//    func fetchVideos(query: String, musicOnly: Bool = true, completion: @escaping ([PipedVideo]) -> Void) {
////        let categoryPart = musicOnly ? "&videoCategoryId=10" : ""
//        // Construct the URL with conditional inclusion of the music category
//        // \(categoryPart)
//        guard let url = URL(string: "\(baseUrl)?search_query=\(query)&type=video") else {
//            print("Invalid URL")
//            return
//        }
//        
//        URLSession.shared.dataTask(with: url) { data, response, error in
//            // Check for errors or no data
//            guard let data = data, error == nil else {
//                print("Piped API request error: \(error?.localizedDescription ?? "Unknown error")")
//                completion([])
//                return
//            }
//            
//            do {
//                if let s = String(data: data, encoding: .utf8) { print(s) }
//                // Decode the JSON response
//                let searchResponse = try JSONDecoder().decode(PipedSearchResponse.self, from: data)
//                // Map each item to a Video, filtering out any without a valid videoId
//                let videos = searchResponse.items.compactMap { item -> YouTubeVideo? in
//                    guard let videoId = item.id.videoId else { return nil }
//                    let thumbnailUrl = item.snippet.thumbnails.medium.url
//                    // Since we don't have a separate audio URL, we pass nil for audioUrl
//                    return PipedVideo(id: videoId, title: item.snippet.title, thumbnailUrl: thumbnailUrl, audioUrl: nil)
//                }
//                
//                // Complete with the array of videos
//                DispatchQueue.main.async {
//                    completion(videos)
//                }
//            } catch {
//                print("Piped API JSON parsing error: \(error)")
//                completion([])
//            }
//        }.resume()
//    }
//}
