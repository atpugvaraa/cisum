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
        guard let url = URL(string: "\(baseUrl)?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&filter=music_songs") else {
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
                // Map each item to an APIVideo, adjusting for the correct structure
                let videos = searchResponse.items.compactMap { item -> APIVideo? in
                    // Directly use the computed `videoId` property of `VideoItem`
                    guard let videoId = item.videoId else { return nil }
                    // No need to guard for snippet existence if you're using other properties of VideoItem
                    let thumbnailUrl = item.thumbnail
                    let videoStream = OStream(url: "https://pipedapi.kavin.rocks/streams/\(videoId)", videoOnly: false)
                    return APIVideo(id: videoId, title: item.title, uploader: item.uploaderName, thumbnailURL: thumbnailUrl, audioStreams: [], videoStreams: [videoStream])
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
