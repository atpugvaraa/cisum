//
//  Search.swift
//  cisum
//
//  Created by Aarav Gupta on 09/03/24.
//

import SwiftUI

struct Search: View {
    @StateObject private var audioPlayerManager = AudioPlayerManager()
    @State private var videos = [YouTubeVideo]()
    @State private var isLoading = false
    @State private var isMusicOnly = true
  @State private var searchText = ""
  var body: some View {
      NavigationView{
          if isLoading {
              loadingView
          } else {
              listContent
          }
          ScrollView(.vertical){
//              VerticalScrollView()
          }.navigationTitle("Search")
      }.searchable(text: $searchText)
  }
    
    private var searchUI: some View {
        VStack {
            TextField("Search YouTube", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button("Search", action: loadVideos).padding()
        }
    }
    private var loadingView: some View {
        ProgressView("Fetching YouTube Videos...")
            .progressViewStyle(.circular)
            .padding()
    }
    
    @ViewBuilder
    var listContent: some View {
        List(videos) { video in
            NavigationLink(destination: VideoDetailView(videoID: video.id)) {
                videoRow(video)
            }
        }
    }
    
    func videoRow(_ video: YouTubeVideo) -> some View {
        HStack(alignment: .center) {
            AsyncImage(url: video.thumbnailUrl) { phase in
                switch phase {
                case .empty: ProgressView()
                case .success(let image): image.resizable().frame(width: 50, height: 50).contentShape(RoundedRectangle(cornerRadius: 5))
                case .failure: Image(systemName: "photo").frame(width: 25, height: 25)
                @unknown default: EmptyView()
                }
            }.padding(.trailing, 10)
            
            Text(video.title).font(.caption).foregroundColor(.primary).lineLimit(1)
        }.frame(height: 60)
    }
    
    private func loadVideos() {
        guard !searchText.isEmpty else { return }
        isLoading = true
        YouTubeService().fetchVideos(query: searchText, musicOnly: isMusicOnly) { videos in
            self.videos = videos
            isLoading = false
        }
    }
}

struct VideoDetailView: View {
    var videoID: String

    var body: some View {
        YouTubePlayerView(videoID: videoID).edgesIgnoringSafeArea(.all)
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

#Preview {
    Search()
}
