//
//  Search.swift
//  cisum
//
//  Created by Aarav Gupta on 09/03/24.
//

import SwiftUI

struct Search: View {
    @StateObject private var audioPlayerManager = AudioPlayerManager()
    @State private var videos = [APIVideo]()
    @State private var isLoading = false
    @State private var isMusicOnly = true
    @State private var searchText = ""
    @Binding var expandPlayer: Bool
    var namespace: Namespace.ID
    
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
    }

    private var loadingView: some View {
        ProgressView("Fetching YouTube Videos...")
            .progressViewStyle(.circular)
            .padding()
    }

    @ViewBuilder
    var listContent: some View {
        List(videos) { video in
            NavigationLink(destination: Player(videoID: "", expandPlayer: $expandPlayer, animation: namespace)) {
                videoRow(video)
            }
        }
    }
    
    func videoRow(_ video: APIVideo) -> some View {
        HStack(alignment: .center) {
            AsyncImage(url: video.thumbnailURL) { phase in
                switch phase {
                case .empty: ProgressView()
                case .success(let image): image.resizable().aspectRatio(contentMode: .fill).frame(width: 75, height: 75).clipShape(RoundedRectangle(cornerRadius: 5))
                case .failure: Image(systemName: "photo").frame(width: 75, height: 75)
                @unknown default: EmptyView()
                }
            }
            
            Text(video.title).font(.caption).foregroundColor(.primary).lineLimit(1)
        }.frame(width: 100, height: 100)
    }

    private func loadVideos() {
        guard !searchText.isEmpty else { return }
        isLoading = true
        APIService().fetchVideos(query: searchText) { videos in
            self.videos = videos
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
