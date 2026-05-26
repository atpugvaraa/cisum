#if os(iOS)
import SwiftUI
import SwiftData
import DesignSystem
import Kingfisher
import Services
import Models
import YouTubeSDK

public struct AlbumView: View {
    let album: Album
    @State private var viewModel = AlbumViewModel()
    @Environment(PlaybackServices.self) private var playbackServices
    @Environment(SearchServices.self) private var searchServices
    @Environment(AppServices.self) private var appServices
    
    @Query private var tracks: [Song]
    
    public init(album: Album) {
        self.album = album
        let albumID = album.albumID
        _tracks = Query(filter: #Predicate<Song> { $0.albumID == albumID })
    }
    
    private var playerViewModel: any PlayerViewModelInterface {
        playbackServices.playerViewModel
    }
    
    public var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 0) {
                    AlbumCover(isCardExpanded: true, viewModel: viewModel, album: album)
                        .frame(width: geo.size.width, height: geo.size.width)
                    
                    VStack(spacing: 0) {
                        HStack {
                            Button {
                                playTracks(startingAt: 0)
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 50)
                                        .fill(viewModel.backgroundColor)
                                    
                                    Text("Play")
                                        .foregroundStyle(viewModel.titleColor.safeTextColor(over: viewModel.backgroundColor) )
                                        .fontWeight(.bold)
                                }
                            }
                            .frame(width: 160, height: 48)
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 24)
                        
                        LazyVStack(spacing: 0) {
                            ForEach(Array(tracks.enumerated()), id: \.element.songID) { index, track in
                                Button {
                                    playTracks(startingAt: index)
                                } label: {
                                    VStack {
                                        HStack {
                                            Text("\(index + 1)")
                                                .font(.caption.monospacedDigit())
                                                .frame(width: 24, alignment: .leading)
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(track.title)
                                                    .lineLimit(1)
                                                
                                                Text(track.primaryArtistName ?? "")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            }
                                            
                                            Spacer()
                                            
                                            Group {
                                                if track.isExplicit {
                                                    Image(systemName: "e.square.fill")
                                                        .foregroundStyle(.secondary)
                                                }
                                                
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
                    .background(viewModel.backgroundColor.opacity(0.1))
                }
            }
            .ignoresSafeArea(edges: .top)
        }
    }
    
    private func playTracks(startingAt index: Int) {
        guard !tracks.isEmpty else { return }
        
        let externalTracks: [ExternalQueueTrack] = tracks.compactMap { track in
            let sourceProvider = track.preferredFallbackProvider ?? .youtube
            let payload: FederatedSearchPayload
            let mediaID: String
            
            if sourceProvider == .spotify, let spotifyID = track.spotifyTrackID {
                mediaID = spotifyID
                let spotifyTrack = SpotifySearchTrack(
                    id: spotifyID,
                    title: track.title,
                    artistName: track.primaryArtistName ?? "",
                    albumName: track.albumTitle,
                    artworkURL: track.artworkURLString.flatMap { URL(string: $0) },
                    durationSeconds: track.durationSeconds ?? 0,
                    previewURL: track.spotifyPreviewURLString.flatMap { URL(string: $0) }
                )
                payload = .spotify(spotifyTrack)
            } else if let ytID = track.youtubeVideoID ?? track.youtubeMusicVideoID {
                mediaID = ytID
                let ytSong = YouTubeMusicSong(
                    id: ytID,
                    title: track.title,
                    artists: [track.primaryArtistName ?? ""].filter { !$0.isEmpty },
                    album: track.albumTitle,
                    duration: track.durationSeconds.map { TimeInterval($0) },
                    thumbnailURL: track.artworkURLString.flatMap { URL(string: $0) },
                    videoId: ytID,
                    isExplicit: track.isExplicit
                )
                payload = .youtubeMusic(ytSong)
            } else {
                return nil
            }

            let item = FederatedSearchItem(
                id: mediaID,
                title: track.title,
                subtitle: track.primaryArtistName ?? "",
                artworkURL: track.artworkURLString.flatMap { URL(string: $0) },
                durationSeconds: track.durationSeconds,
                isPlayable: true,
                isExplicit: track.isExplicit,
                audioQualityLabel: nil,
                audioCodecLabel: nil,
                payload: payload
            )
            
            return ExternalQueueTrack(
                mediaID: mediaID,
                title: track.title,
                artist: track.primaryArtistName ?? "",
                artworkURL: track.artworkURLString.flatMap { URL(string: $0) } ?? (album.artworkURLString.flatMap { URL(string: $0) }),
                service: sourceProvider == .spotify ? .spotify : .youtube,
                isExplicit: track.isExplicit,
                qualityLabelHint: nil,
                codecLabelHint: nil,
                resolvePayload: {
                    guard let resolved = try await searchServices.searchViewModel.resolveExternalStream(for: item) else {
                        throw NSError(domain: "AlbumView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to resolve stream"])
                    }
                    return resolved
                }
            )
        }
        
        playerViewModel.setQueue(externalTracks, startIndex: index)
        appServices.playerPresentationController.expand()
    }
}
#endif
