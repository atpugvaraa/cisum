#if os(iOS)
import SwiftUI
import SwiftData
import Services
import Models
import Kingfisher
import YouTubeSDK

public struct ArtistView: View {
    let artist: Artist
    @State private var palette: ImageColorPalette?
    @Environment(PlaybackServices.self) private var playbackServices
    @Environment(SearchServices.self) private var searchServices
    @Environment(AppServices.self) private var appServices
    
    @Query private var topTracks: [Song]
    
    public init(artist: Artist) {
        self.artist = artist
        let artistID = artist.artistID
        _topTracks = Query(filter: #Predicate<Song> { $0.primaryArtistID == artistID })
    }
    
    private var playerViewModel: any PlayerViewModelInterface {
        playbackServices.playerViewModel
    }
    
    public var body: some View {
        GeometryReader { geo in
            let size = geo.size
            
            ZStack {
                (palette?.background ?? .pink)
                
                ScrollView {
                    if let artwork = artist.artworkURLString, let artworkURL = URL(string: artwork) {
                        KFImage(artworkURL)
                            .resizable()
                            .scaledToFill()
                            .frame(width: size.width, height: size.width)
                            .clipped()
                            .overlay {
                                ZStack {
                                    LinearGradient(colors: [(palette?.background ?? .pink), (palette?.background ?? .pink).opacity(0.2), .clear, .clear, .clear, .clear], startPoint: .bottom, endPoint: .top)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                                    
                                    HStack {
                                        Text(artist.displayName)
                                            .font(.largeTitle)
                                            .bold()
                                            .foregroundStyle(palette?.title.safeTextColor(over: palette?.background ?? .black) ?? .white)
                                        
                                        Spacer()
                                        
                                        Button {
                                            if !topTracks.isEmpty {
                                                playTracks(startingAt: Int.random(in: 0..<topTracks.count))
                                            }
                                        } label: {
                                            Image(systemName: "shuffle")
                                                .padding()
                                                .background(
                                                    Circle()
                                                        .foregroundStyle(.black.opacity(0.2))
                                                )
                                                .foregroundStyle(palette?.background ?? .black)
                                        }
                                        .buttonStyle(.plain)
                                        
                                        Button {
                                            playTracks(startingAt: 0)
                                        } label: {
                                            Image(systemName: "play.fill")
                                                .padding()
                                                .background(
                                                    Circle()
                                                        .foregroundStyle(palette?.title.safeTextColor(over: palette?.background ?? .black) ?? .black)
                                                )
                                                .foregroundStyle(palette?.background ?? .white)
                                                .foregroundStyle((palette?.dominant ?? .pink).opacity(0.4))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                                    .padding()
                                }
                            }
                            .task {
                                let tinyURL = ImageColorExtractor.paletteURL(from: artworkURL)
                                KingfisherManager.shared.retrieveImage(with: tinyURL) { result in
                                    guard case .success(let value) = result,
                                          let data = value.image.pngData() else { return }
                                    
                                    Task {
                                        let extractedPalette = await ImageColorExtractor.shared.extractPalette(from: data, cacheKey: artworkURL.absoluteString)
                                        await MainActor.run { self.palette = extractedPalette }
                                    }
                                }
                            }
                    }
                    
                    ArtistTopSongs(artist: artist, onPlayTrack: { index in
                        playTracks(startingAt: index)
                    })
                    
                    ArtistDiscography(artist: artist)
                }
            }
        }
        .ignoresSafeArea()
    }
    
    private func playTracks(startingAt index: Int) {
        guard !topTracks.isEmpty else { return }
        
        let externalTracks: [ExternalQueueTrack] = topTracks.compactMap { track in
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
                artworkURL: track.artworkURLString.flatMap { URL(string: $0) } ?? (artist.artworkURLString.flatMap { URL(string: $0) }),
                service: sourceProvider == .spotify ? .spotify : .youtube,
                isExplicit: track.isExplicit,
                qualityLabelHint: nil,
                codecLabelHint: nil,
                resolvePayload: {
                    guard let resolved = try await searchServices.searchViewModel.resolveExternalStream(for: item) else {
                        throw NSError(domain: "ArtistView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to resolve stream"])
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
