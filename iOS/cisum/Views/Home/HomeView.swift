//
//  HomeView.swift
//  cisum
//
//  Created by Aarav Gupta on 15/03/26.
//

import SwiftUI
import YouTubeSDK

struct HomeView: View {
    @Environment(\.youtube) private var youtube

    @State private var viewModel = HomeViewModel()
    
    #if DEBUG
    @ObserveInjection var forceRedraw
    #endif

    var body: some View {
        ZStack {
            Color.black
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if viewModel.isLoading && viewModel.items.isEmpty {
                        ProgressView("Loading Home Feed...")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 16)
                            .tint(.white)
                    }

                    if let errorMessage = viewModel.errorMessage, viewModel.items.isEmpty {
                        ContentUnavailableView(
                            "Unable to Load Home",
                            systemImage: "wifi.exclamationmark",
                            description: Text(errorMessage)
                        )
                        .foregroundStyle(.white)

                        Button("Retry") {
                            Task {
                                await viewModel.refresh()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                        HomeFeedRow(item: item)
                            .onAppear {
                                viewModel.loadMoreIfNeeded(currentIndex: index, totalCount: viewModel.items.count)
                            }
                    }

                    if viewModel.isLoadingMore {
                        ProgressView("Loading More...")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                            .tint(.white)
                    }

                    if let footerMessage = viewModel.footerMessage, !viewModel.items.isEmpty {
                        Text(footerMessage)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.72))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 6)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 120)
            }
            .ignoresSafeArea()
            .contentMargins(.top, 140)
        }
        .ignoresSafeArea()
        .overlay {
            ZStack {
                VStack(alignment: .leading) {
                    Text("Welcome back,")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Aarav Gupta")
                        .font(.title)
                        .fontWeight(.semibold)
                }
                .padding(.top, 22)
                .padding(.leading)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                
                ProfileButton()
            }
            .padding(.top, 200)
        }
        .task {
            viewModel.configure(youtube: youtube)
            await viewModel.loadIfNeeded()
        }
        .refreshable {
            await viewModel.refresh()
        }
        .enableInjection()
    }
}

private struct HomeFeedRow: View {
    let item: HomeFeedItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: symbolName)
                    .foregroundStyle(.white)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.08))
        )
    }

    private var title: String {
        switch item {
        case .musicSong(let song):
            return normalizedMusicDisplayTitle(song.title, artist: song.artistsDisplay)
        case .musicAlbum(let album):
            return normalizedMusicDisplayTitle(album.title, artist: album.artist)
        case .musicArtist(let artist):
            return normalizedMusicDisplayTitle(artist.name)
        case .musicPlaylist(let playlist):
            return normalizedMusicDisplayTitle(playlist.title, artist: playlist.author)
        case .main(let sourceItem):
            switch sourceItem {
            case .video(let video):
                return normalizedMusicDisplayTitle(video.title, artist: video.author)
            case .song(let song):
                return normalizedMusicDisplayTitle(song.title, artist: song.artistsDisplay)
            case .playlist(let playlist):
                return normalizedMusicDisplayTitle(playlist.title, artist: playlist.author)
            case .channel(let channel):
                return normalizedMusicDisplayTitle(channel.title)
            case .shelf(let shelf):
                return normalizedMusicDisplayTitle(shelf.title)
            }
        }
    }

    private var subtitle: String {
        switch item {
        case .musicSong(let song):
            let album = song.album ?? "Single"
            return "\(normalizedMusicDisplayArtist(song.artistsDisplay, title: song.title)) • \(album)"
        case .musicAlbum(let album):
            let artist = album.artist ?? "Album"
            if let year = album.year, !year.isEmpty {
                return "\(artist) • \(year)"
            }
            return artist
        case .musicArtist(let artist):
            return artist.subscriberCount ?? "Artist"
        case .musicPlaylist(let playlist):
            let author = playlist.author ?? "Playlist"
            if let count = playlist.count, !count.isEmpty {
                return "\(author) • \(count)"
            }
            return author
        case .main(let sourceItem):
            switch sourceItem {
            case .video(let video):
                return normalizedMusicDisplayArtist(video.author, title: video.title)
            case .song(let song):
                let album = song.album ?? "Single"
                return "\(normalizedMusicDisplayArtist(song.artistsDisplay, title: song.title)) • \(album)"
            case .playlist(let playlist):
                return playlist.author ?? "Playlist"
            case .channel(let channel):
                return channel.subscriberCount ?? "Channel"
            case .shelf(let shelf):
                return "\(shelf.items.count) item\(shelf.items.count == 1 ? "" : "s")"
            }
        }
    }

    private var symbolName: String {
        switch item {
        case .musicSong:
            return "music.note"
        case .musicAlbum:
            return "square.stack.fill"
        case .musicArtist:
            return "person.crop.square"
        case .musicPlaylist:
            return "music.note.list"
        case .main(let sourceItem):
            switch sourceItem {
            case .video:
                return "play.rectangle.fill"
            case .song:
                return "music.note"
            case .playlist:
                return "music.note.list"
            case .channel:
                return "person.crop.circle"
            case .shelf:
                return "square.grid.2x2.fill"
            }
        }
    }
}
