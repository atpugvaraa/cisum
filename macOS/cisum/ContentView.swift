//
//  ContentView.swift
//  cisum
//
//  Created by Aarav Gupta on 18/03/26.
//

import SwiftUI
import iTunesKit
import AVKit

struct SongRow: View {
    let result: iTunesSearchResult

    private var artworkURL: URL? {
        guard let artworkUrl100 = result.artworkUrl100 else { return nil }

        let decoded = artworkUrl100.removingPercentEncoding ?? artworkUrl100
        let candidates = [
            decoded.replacingOccurrences(of: "100x100", with: "1500x1500"),
            decoded.replacingOccurrences(of: "100bb", with: "1500bb"),
            decoded.replacingOccurrences(of: "%7Bw%7Dx%7Bh%7Dbb.%7Bf%7D", with: "1500x1500bb.jpg")
        ]

        for candidate in candidates {
            if let url = URL(string: candidate) {
                return url
            }
        }

        return URL(string: decoded)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            if let url = artworkURL {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(8)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                }
                .frame(width: 50, height: 50)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.trackName ?? "Unknown Track")
                    .font(.headline)
                    .lineLimit(1)
                
                Text(result.artistName ?? "Unknown Artist")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ContentView: View {
    private let client = iTunesKit()
    
    @State private var searchText = ""
    @State private var results: [iTunesSearchResult] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    
    // Video Playback State
    @State private var videoURL: URL?
    @State private var isFetchingVideo = false
    @State private var showingPlayer = false
    @State private var player: AVPlayer?

    var body: some View {
        NavigationStack {
            ZStack {
                if results.isEmpty && !isSearching {
                    ContentUnavailableView(
                        "Search for Songs",
                        systemImage: "music.note",
                        description: Text("Find your favorite tracks on iTunes.")
                    )
                } else {
                    List(results, id: \.self) { result in
                        Button {
                            fetchVideoAndPlay(for: result)
                        } label: {
                            SongRow(result: result)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.inset)
                }
                
                if isSearching || isFetchingVideo {
                    ProgressView(isSearching ? "Searching..." : "Fetching Video...")
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                }
            }
            .navigationTitle("iTunes Search")
            .sheet(isPresented: $showingPlayer, onDismiss: { player?.pause(); player = nil }) {
                if let player = player {
                    VideoPlayer(player: player)
                        .ignoresSafeArea()
                        .frame(minWidth: 400, minHeight: 600)
                }
            }
            .searchable(text: $searchText, prompt: "Search artists, songs...")
            .onSubmit(of: .search) {
                performSearch()
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                if let errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        
        isSearching = true
        results = []
        errorMessage = nil
        
        Task {
            do {
                let songs = try await client.searchSongs(term: searchText)
                await MainActor.run {
                    self.results = songs
                    self.isSearching = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isSearching = false
                }
            }
        }
    }
    
    private func fetchVideoAndPlay(for result: iTunesSearchResult) {
        guard let trackId = result.trackId else { return }
        
        isFetchingVideo = true
        errorMessage = nil
        
        Task {
            do {
                let tokenService = iTunesWebTokenService()
                let webClient = iTunesWebServiceClient(tokenService: tokenService)
                let catalogService = WebCatalogService(client: webClient)
                
                let songId = String(trackId)
                let response = try await catalogService.fetchSongDetails(songId: songId)
                
                // Extract video URL
                if let song = response.resources.songs[songId],
                   let albumId = song.relationships?.albums.data.first?.id,
                   let album = response.resources.albums[albumId] {
                    
                    let videoUrlString = album.attributes.editorialVideo.motionDetailTall.video
                    if let url = URL(string: videoUrlString) {
                        await MainActor.run {
                            self.videoURL = url
                            self.player = AVPlayer(url: url)
                            self.showingPlayer = true
                            self.isFetchingVideo = false
                            self.player?.play()
                        }
                    } else {
                        throw URLError(.badURL)
                    }
                } else {
                    await MainActor.run {
                        self.errorMessage = "Could not find motion video for this song."
                        self.isFetchingVideo = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Error fetching catalog: \(error.localizedDescription)"
                    self.isFetchingVideo = false
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
