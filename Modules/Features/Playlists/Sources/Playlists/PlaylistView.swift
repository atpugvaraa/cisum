//
//  PlaylistView.swift
//  Playlists
//
//  Created by Aarav Gupta on 29/04/26.
//

import SwiftUI
import SwiftData
import Models
import Services
import Kingfisher
import YouTubeSDK

public struct PlaylistView: View {
    let playlist: Playlist
    @Query private var tracks: [PlaylistItem]

    @Environment(AppServices.self) private var appServices
    @Environment(SearchServices.self) private var searchServices
    @Environment(PlaybackServices.self) private var playbackServices

    @State private var showPlaybackAlert = false
    @State private var playbackAlertMessage = ""
    
    public init(playlist: Playlist) {
        self.playlist = playlist
        let playlistID = playlist.playlistID
        _tracks = Query(
            filter: #Predicate<PlaylistItem> { $0.playlistID == playlistID },
            sort: \.sortIndex
        )
    }

    private var searchViewModel: any SearchViewModelInterface {
        searchServices.searchViewModel
    }

    private var playerViewModel: any PlayerViewModelInterface {
        playbackServices.playerViewModel
    }

    private var presentationController: PlayerPresentationController {
        appServices.playerPresentationController
    }
    
    public var body: some View {
        GeometryReader { geo in
            let size = geo.size
            
            ZStack {
                LinearGradient(colors: [.black, .accentColor, .accentColor, .accentColor], startPoint: .bottom, endPoint: .top)
                
                ScrollView {
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: size.width, height: size.width)
                        .overlay {
                            if let artwork = playlist.artworkURLString, let artworkURL = URL(string: artwork) {
                                KFImage(artworkURL)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: size.width, height: size.width)
                                    .clipped()
                            }
                        }
                        .overlay {
                            VStack(alignment: .leading) {
                                Text(playlist.title)
                                    .font(.largeTitle)
                                    .fontWeight(.semibold)
                                
                                if let owner = playlist.ownerName {
                                    Button {
                                        
                                    } label: {
                                        HStack(spacing: 4) {
                                            Text(owner)
                                                .textCase(.uppercase)
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.callout)
                                        }
                                        .fontWeight(.semibold)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                            .padding()
                            .background(
                                LinearGradient(colors: [.black.opacity(0.7), .clear], startPoint: .bottom, endPoint: .center)
                            )
                        }
                    
                    HStack {
                        Button {
                            Task {
                                await playPlaylist(startingAt: 0)
                            }
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 50)
                                    .fill(Color.accentColor)
                                
                                Text("Play")
                                    .foregroundStyle(.white)
                                    .fontWeight(.bold)
                            }
                        }
                        .frame(width: 160, height: 48)
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical)
                    
                    LazyVStack(spacing: 0) {
                        ForEach(Array(tracks.enumerated()), id: \.element.itemKey) { index, track in
                            Button {
                                Task {
                                    await playPlaylist(startingAt: index)
                                }
                            } label: {
                                VStack {
                                    HStack {
                                        Text("\(index + 1)")
                                            .font(.caption.monospacedDigit())
                                            .frame(width: 24, alignment: .leading)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(track.title)
                                                .lineLimit(1)
                                            
                                            Text(track.artistName ?? "")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                        
                                        Spacer()
                                        
                                        Group {
                                            Menu {
                                                Button {
                                                    
                                                } label: {
                                                    Text("Download")
                                                }
                                            } label: {
                                                Image(systemName: "ellipsis")
                                            }
                                            .menuStyle(.button)
                                            .buttonStyle(.plain)
                                        }
                                        .font(.system(size: 20))
                                    }
                                    .fontWeight(.semibold)
                                }
                                .padding()
                            }
                            .buttonStyle(.plain)
                            
                            Divider()
                                .padding(.horizontal)
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
        .alert(playbackAlertMessage, isPresented: $showPlaybackAlert) {
            Button("OK", role: .cancel) {}
        }
    }

    private func playPlaylist(startingAt index: Int) async {
        guard tracks.indices.contains(index) else { return }

        let queueTracks = tracks.compactMap(makePlayableQueueTrack(for:))
        guard !queueTracks.isEmpty else {
            playbackAlertMessage = "This playlist does not have any playable tracks yet."
            showPlaybackAlert = true
            return
        }

        let selectedItem = tracks[index]
        let selectedMediaID = playbackMediaID(for: selectedItem)
        guard let startIndex = queueTracks.firstIndex(where: { $0.mediaID == selectedMediaID }) else {
            playbackAlertMessage = "Unable to start playback for the selected track."
            showPlaybackAlert = true
            return
        }

        playerViewModel.setQueue(queueTracks, startIndex: startIndex)
        presentationController.expand()
    }

    private func makePlayableQueueTrack(for track: PlaylistItem) -> ExternalQueueTrack {
        let artworkURL = track.artworkURLString.flatMap { URL(string: $0) }
        let searchItem = makeSearchItem(for: track, artworkURL: artworkURL)

        return ExternalQueueTrack(
            mediaID: playbackMediaID(for: track),
            title: track.title,
            artist: track.artistName ?? "",
            artworkURL: artworkURL,
            service: searchItem.service,
            isExplicit: false,
            qualityLabelHint: nil,
            codecLabelHint: nil,
            resolvePayload: {
                guard let resolved = try await searchViewModel.resolveExternalStream(for: searchItem) else {
                    throw FederatedSearchError.noPlayableStream(
                        "Unable to resolve a playable stream for \"\(track.title)\"."
                    )
                }
                return resolved
            }
        )
    }

    private func playbackMediaID(for track: PlaylistItem) -> String {
        if let resolvedMediaID = track.resolvedMediaID?.trimmingCharacters(in: .whitespacesAndNewlines),
           !resolvedMediaID.isEmpty {
            return resolvedMediaID
        }

        return track.itemKey
    }

    private func makeSearchItem(for track: PlaylistItem, artworkURL: URL?) -> FederatedSearchItem {
        let artistName = track.artistName ?? ""
        let duration = track.durationSeconds

        if let resolvedMediaID = track.resolvedMediaID, !resolvedMediaID.isEmpty {
            let youtubeSong = YouTubeMusicSong(
                id: resolvedMediaID,
                title: track.title,
                artists: [artistName].filter { !$0.isEmpty },
                album: track.albumName,
                duration: duration.map { TimeInterval($0) },
                thumbnailURL: artworkURL,
                videoId: resolvedMediaID,
                isExplicit: false
            )

            return FederatedSearchItem(
                id: resolvedMediaID,
                title: track.title,
                subtitle: artistName.isEmpty ? (track.albumName ?? "YouTube") : artistName,
                artworkURL: artworkURL,
                durationSeconds: duration,
                isPlayable: true,
                isExplicit: false,
                audioQualityLabel: nil,
                audioCodecLabel: nil,
                payload: .youtubeMusic(youtubeSong)
            )
        }

        switch playlist.sourceProvider {
        default:
            let youtubeID = track.sourceTrackID ?? track.itemKey
            guard let youtubeVideo = makeSyntheticYouTubeVideo(
                videoID: youtubeID,
                title: track.title,
                author: artistName,
                durationSeconds: duration,
                artworkURL: artworkURL
            ) else {
                return makeFallbackSpotifyItem(for: track, artworkURL: artworkURL)
            }

            return FederatedSearchItem(
                id: youtubeID,
                title: track.title,
                subtitle: artistName.isEmpty ? (track.albumName ?? "YouTube") : artistName,
                artworkURL: artworkURL,
                durationSeconds: duration,
                isPlayable: true,
                isExplicit: false,
                audioQualityLabel: nil,
                audioCodecLabel: nil,
                payload: .youtubeVideo(youtubeVideo)
            )

//        default:
//            let spotifyID = track.sourceTrackID ?? track.itemKey
//            let spotifyTrack = SpotifySearchTrack(
//                id: spotifyID,
//                title: track.title,
//                artistName: artistName,
//                albumName: track.albumName,
//                artworkURL: artworkURL,
//                durationSeconds: duration ?? 0,
//                previewURL: nil
//            )
//
//            return FederatedSearchItem(
//                id: "spotify-\(spotifyID)",
//                title: track.title,
//                subtitle: artistName.isEmpty ? (track.albumName ?? "Spotify") : artistName,
//                artworkURL: artworkURL,
//                durationSeconds: duration,
//                isPlayable: true,
//                isExplicit: false,
//                audioQualityLabel: nil,
//                audioCodecLabel: nil,
//                payload: .spotify(spotifyTrack)
//            )
        }
    }

    private func makeFallbackSpotifyItem(for track: PlaylistItem, artworkURL: URL?) -> FederatedSearchItem {
        let artistName = track.artistName ?? ""
        let spotifyID = track.sourceTrackID ?? track.itemKey
        let spotifyTrack = SpotifySearchTrack(
            id: spotifyID,
            title: track.title,
            artistName: artistName,
            albumName: track.albumName,
            artworkURL: artworkURL,
            durationSeconds: track.durationSeconds ?? 0,
            previewURL: nil
        )

        return FederatedSearchItem(
            id: "spotify-\(spotifyID)",
            title: track.title,
            subtitle: artistName.isEmpty ? (track.albumName ?? "Spotify") : artistName,
            artworkURL: artworkURL,
            durationSeconds: track.durationSeconds,
            isPlayable: true,
            isExplicit: false,
            audioQualityLabel: nil,
            audioCodecLabel: nil,
            payload: .spotify(spotifyTrack)
        )
    }

    private func makeSyntheticYouTubeVideo(
        videoID: String,
        title: String,
        author: String,
        durationSeconds: Double?,
        artworkURL: URL?
    ) -> YouTubeVideo? {
        var videoDetails: [String: Any] = [
            "videoId": videoID,
            "title": title,
            "viewCount": "0",
            "author": author,
            "channelId": "",
            "shortDescription": "",
        ]

        if let durationSeconds {
            videoDetails["lengthSeconds"] = String(Int(durationSeconds))
        }

        if let artworkURL {
            videoDetails["thumbnail"] = [
                "thumbnails": [
                    ["url": artworkURL.absoluteString, "width": 0, "height": 0]
                ]
            ]
        }

        let root: [String: Any] = ["videoDetails": videoDetails]
        guard JSONSerialization.isValidJSONObject(root),
              let data = try? JSONSerialization.data(withJSONObject: root)
        else {
            return nil
        }

        return try? JSONDecoder().decode(YouTubeVideo.self, from: data)
    }
}
