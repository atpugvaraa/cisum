////
////  YouTube API.swift
////  cisum
////
////  Created by Aarav Gupta on 28/02/24.
////
//import SwiftUI
//import AVKit
//
//struct Video: Identifiable {
//    let id: String
//    let title: String
//    let videoURL: URL
//}
//
//class YouTubeAPI {
//    static let apiKey = "AIzaSyCJdWwrkc4GTQYwCkIFQfFFTa6nckP7R4Y"
//    static let baseURL = "https://www.googleapis.com/youtube/v3"
//
//    static func fetchVideos(completion: @escaping ([Video]) -> Void) {
//        let urlString = "\(baseURL)/search?key=\(apiKey)&part=snippet&q=swiftui"
//        guard let url = URL(string: urlString) else {
//            completion([])
//            return
//        }
//
//        URLSession.shared.dataTask(with: url) { data, response, error in
//            guard let data = data, error == nil else {
//                completion([])
//                return
//            }
//
//            do {
//                let response = try JSONDecoder().decode(YouTubeResponse.self, from: data)
//                let videos = response.items.map { item -> Video in
//                    let videoId = item.id.videoId
//                    let title = item.snippet.title
//                    let videoURL = URL(string: "https://www.youtube.com/watch?v=\(videoId)")!
//                    return Video(id: videoId, title: title, videoURL: videoURL)
//                }
//                completion(videos)
//            } catch {
//                print("Error decoding JSON: \(error)")
//                completion([])
//            }
//        }.resume()
//    }
//}
//
//struct YouTubeResponse: Decodable {
//    let items: [Item]
//
//    struct Item: Decodable {
//        let id: Id
//        let snippet: Snippet
//
//        struct Id: Decodable {
//            let videoId: String
//        }
//
//        struct Snippet: Decodable {
//            let title: String
//        }
//    }
//}
//
//struct VideoPlayerView: View {
//    let videoURL: URL
//
//    var body: some View {
//        VStack {
//            VideoPlayer(player: AVPlayer(url: videoURL))
//                .frame(height: 300)
//                .onAppear {
//                    // Autoplay video if needed
//                }
//        }
//    }
//}
//
//struct VideoListView: View {
//    @State private var videos: [Video] = []
//    @State private var selectedVideo: Video?
//
//    var body: some View {
//        NavigationView {
//            List(videos) { video in
//                Button(action: {
//                    self.selectedVideo = video
//                }) {
//                    Text(video.title)
//                }
//            }
//            .sheet(item: $selectedVideo) { video in
//                VideoPlayerView(videoURL: video.videoURL)
//            }
//            .navigationBarTitle("Videos")
//        }
//        .onAppear {
//            YouTubeAPI.fetchVideos { videos in
//                self.videos = videos
//            }
//        }
//    }
//}
