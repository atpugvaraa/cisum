//
//  Search.swift
//  cisum
//
//  Created by Aarav Gupta on 09/03/24.
//

import SwiftUI

struct AlertMessage: Identifiable {
    let id = UUID() // Automatically provides a unique identifier
    let message: String
}


struct SearchView: View {
    @StateObject private var audioPlayerManager = AudioPlayerManager()
    @State private var videos = [APIVideo]()
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var errorMessage: AlertMessage?
    @Binding var expandPlayer: Bool
    @Namespace private var animation

    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    loadingView
                } else if videos.isEmpty && !searchText.isEmpty {
                    emptyStateView
                } else {
                    listContent
                }
            }
            .navigationTitle("Search")
            .searchable(text: $searchText)
            .onChange(of: searchText, perform: loadVideos)
            .alert(item: $errorMessage) { errorMessage in
                Alert(title: Text("Error"), message: Text(errorMessage.message), dismissButton: .default(Text("OK")))
            }
        }
    }

    private var loadingView: some View {
        ProgressView("Loading...")
            .progressViewStyle(.circular)
            .padding()
    }

    private var emptyStateView: some View {
        Text("No videos found for the search query.")
            .padding()
            .foregroundColor(.gray)
    }

    private var listContent: some View {
        ScrollView {
            LazyVStack {
                ForEach(videos) { video in
                    videoRow(video)
                }
            }
        }
    }
    
    private func videoRow(_ video: APIVideo) -> some View {
        NavigationLink(destination: Player(videoID: video.id, expandPlayer: .constant(true), animation: animation)) {
            HStack {
                AsyncImage(url: URL(string: video.thumbnailURL)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 70, height: 70)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .matchedGeometryEffect(id: video.id, in: animation)
                    case .failure:
                        Image(systemName: "music.note")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 70, height: 70)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 75, height: 75)
                
                Text(video.title)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: 343, height: 75, alignment: .leading)
            .padding(.vertical, 4)
        }
        .onTapGesture {
            expandPlayer = true
        }
//        .buttonStyle(PlainButtonStyle())
    }

    private func loadVideos(for query: String) {
        guard !query.isEmpty else {
            videos = []
//            errorMessage = AlertMessage(message: "Please enter a search term.")
            return
        }

        isLoading = true
        APIService().fetchVideos(query: query) { fetchedVideos in
            DispatchQueue.main.async {
                self.isLoading = false
                if fetchedVideos.isEmpty {
//                    self.errorMessage = AlertMessage(message: "No videos found for \"\(query)\".")
                } else {
                    self.videos = fetchedVideos
                }
            }
        }
    }
}
