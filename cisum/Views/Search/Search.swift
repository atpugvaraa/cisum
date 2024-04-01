//
//  Search.swift
//  cisum
//
//  Created by Aarav Gupta on 09/03/24.
//

import SwiftUI

struct VideoIDWrapper: Identifiable {
    let id: String
}


struct Search: View {
    var videoID: String
    @StateObject private var audioPlayerManager = AudioPlayerManager()
    @State private var videos = [APIVideo]() // Fix 1: Change to [APIVideo]
    @State private var isLoading = false
    @State private var searchText = ""
    @Binding var expandPlayer: Bool
    var namespace: Namespace.ID
    
    @State private var selectedVideo: VideoIDWrapper?

    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    loadingView
                } else {
                    listContent
                }
            }
            .navigationTitle("Search")
        }
        .searchable(text: $searchText)
        .onChange(of: searchText, perform: { searchText in
            loadVideos()
        })
        .sheet(item: $selectedVideo, onDismiss: {
        }) { wrapper in
            Player(videoID: videoID, expandPlayer: $expandPlayer, animation: namespace)
        }
    }
    
    private var loadingView: some View {
        ProgressView("loading...")
            .progressViewStyle(.circular)
            .padding()
    }
    
        @ViewBuilder
        var listContent: some View {
            List(videos) { video in
                NavigationLink(destination: APIPlayer(videoID: video.id)) {
                    videoRow(video)
                }
            }
        }
    
//    @ViewBuilder
//    var listContent: some View {
//        List(videos) { video in
//            Button(action: {
//                self.selectedVideo = VideoIDWrapper(id: video.id)
//            }) {
//                videoRow(video)
//            }
//        }
//    }
    
    func videoRow(_ video: APIVideo) -> some View { // Fix 2: Change argument type to APIVideo
        HStack(alignment: .center) {
            AsyncImage(url: URL(string: video.thumbnailURL)) { phase in
                switch phase {
                case .empty: ProgressView()
                case .success(let image):
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 75, height: 75)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .matchedGeometryEffect(id: video.id, in: namespace) // Use matched geometry effect
                case .failure: Image(systemName: "photo").frame(width: 75, height: 75)
                @unknown default: EmptyView()
                }
                
                Text(video.title).font(.caption).foregroundColor(.primary).lineLimit(1)
            }.frame(width: 100, height: 100)
        }
    }

    private func loadVideos() {
        guard !searchText.isEmpty else { return }
        isLoading = true
        let APIService = APIService()
        APIService.fetchVideos(query: searchText) { fetchedVideos in
            if fetchedVideos.isEmpty {
                print("No videos found for the search query: \(searchText)")
            }
            self.videos = fetchedVideos
            isLoading = false
        }
    }

}
//struct VerticalScrollView: View {
//    var body: some View {
//        ScrollView(.vertical){
//
//
//            HStack(spacing:10) {
//                VerticalRowCard(Image1: "Cat1", Text1: "Pop")
//                VerticalRowCard(Image1: "Cat1", Text1: "Rock")
//            }.padding()
//            HStack(spacing:10) {
//                VerticalRowCard(Image1: "Cat2", Text1: "Pop")
//                VerticalRowCard(Image1: "Cat2", Text1: "Rock")
//            }.padding()
//            HStack(spacing:10) {
//                VerticalRowCard(Image1: "Cat3", Text1: "Pop")
//                VerticalRowCard(Image1: "Cat3", Text1: "Rock")
//            }.padding()
//            HStack(spacing:10) {
//                VerticalRowCard(Image1: "Cat5", Text1: "Pop")
//                VerticalRowCard(Image1: "Cat5", Text1: "Rock")
//            }.padding()
//
//            HStack(spacing:10) {
//                VerticalRowCard(Image1: "Cat1", Text1: "Pop")
//                VerticalRowCard(Image1: "Cat1", Text1: "Rock")
//            }.padding()
//            HStack(spacing:10) {
//                VerticalRowCard(Image1: "Cat2", Text1: "Pop")
//                VerticalRowCard(Image1: "Cat2", Text1: "Rock")
//            }.padding()
//            HStack(spacing:10) {
//                VerticalRowCard(Image1: "Cat3", Text1: "Pop")
//                VerticalRowCard(Image1: "Cat3", Text1: "Rock")
//            }.padding()
//            HStack(spacing:10) {
//                VerticalRowCard(Image1: "Cat5", Text1: "Pop")
//                VerticalRowCard(Image1: "Cat5", Text1: "Rock")
//            }.padding()
//
//        }
//    }
//}
//
//struct VerticalRowCard: View {
//    let Image1:String
//    let Text1:String
//    var body: some View {
//        ZStack(alignment:.bottomLeading) {
//            Image(Image1)
//                .resizable()
//                .scaledToFit()
//
//
//            Text(Text1)
//                .fontWeight(.bold)
//                .font(.caption2)
//                .padding(.leading)
//                .padding(.bottom)
//
//        }.cornerRadius(20)
//            .shadow(color: .white, radius: 2)
//    }
//}
