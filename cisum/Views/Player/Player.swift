//
//  Player.swift
//  cisum
//
//  Created by Aarav Gupta on 09/03/24.
//

import SwiftUI
import AVKit
import YouTubeResponder
import SDWebImageSwiftUI

struct Player: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @StateObject private var searchViewModel = SearchViewModel()
    var animation: Namespace.ID
    @Binding var expandPlayer: Bool
    var videoID: String
    var title: String? = nil
    var artistName: String? = nil
    var thumbnailURL: String? = nil
    var keyword: String {"\(viewModel.artistName ?? "") \(viewModel.title ?? "")" }
    
    // State variables
    @State private var activePage: pql = .player
    @State private var activeTab: songorvideo = .song
    @State private var animateContent: Bool = false
    @State private var offsetY: CGFloat = 0
    @State private var liked: Bool = false
    @State private var isPlaying: Bool = true
    @State private var isCommenting: Bool = false
    @State private var transparency: Double = 0.0
    @State private var currentTime: TimeInterval = 0
    @State private var volume: Double = 0
    @State private var color: Color = .white
    
    // Define the accent color
    private let accentColor = Color(red: 0.976, green: 0.176, blue: 0.282, opacity: 0.3)
    private var normalFillColor: Color { color.opacity(0.5) }
    private var emptyColor: Color { color.opacity(0.3) }
    
    // Constants for max duration and volume
    var maxDuration: TimeInterval {
        max(TimeInterval(viewModel.duration ?? 1), 0.1) - 0.1
    }
    private let maxVolume: Double = 1
    @State private var player: AVPlayer = AVPlayer()
    
    var body: some View {
        GeometryReader {
            let size = $0.size
            let safeArea = $0.safeAreaInsets
            
            ZStack {
                dynamicBackground()
                
                VStack(spacing: 15) {
                    if activePage == .player {
                        VStack(spacing: 15) {
                            SongOrVideo(tabs: songorvideo.allCases, activeTab: $activeTab, height: 35, font: .body, activeTint: .primary, inActiveTint: .secondary) { size in
                                RoundedRectangle(cornerRadius: 30)
                                    .fill(accentColor)
                                    .frame(height: size.height)
                                    .frame(maxHeight: .infinity, alignment: .bottom)
                            }
                            .padding(.horizontal, 15)
                            .padding(.vertical, 15)
                            .toolbarBackground(.hidden, for: .navigationBar)
                        }
                        .frame(width: 210, height: 35)
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : size.height)
                        
                        VStack {
                            GeometryReader {
                                let size = $0.size
                                
                                if activeTab == .song {
                                    ZStack {
                                        VideoPlayer(player: self.player)
                                            .opacity(animateContent ? 1 : 0)
                                            .offset(y: animateContent ? 0 : size.height)
                                            .allowsHitTesting(false)
                                            .frame(width: isPlaying ? size.width : 250, height: isPlaying ? size.height : 250)
                                            .clipShape(RoundedRectangle(cornerRadius: animateContent ? 15 : 5, style: .continuous))
                                            .animation(.easeInOut(duration: 0.3), value: isPlaying)
                                        
                                        AnyView(
                                            WebImage(url: URL(string: viewModel.thumbnailURL ?? "musicnote")) { phase in
                                                switch phase {
                                                case .success(let image):
                                                    image.resizable()
                                                        .interpolation(.high)
                                                        .scaledToFit()
                                                        .frame(width: isPlaying ? size.width : 250, height: isPlaying ? size.height : 250)
                                                        .clipShape(RoundedRectangle(cornerRadius: animateContent ? 15 : 5, style: .continuous))
                                                        .animation(.easeInOut(duration: 0.3), value: isPlaying) // Add animation for smooth expand
                                                case .failure, .empty:
                                                    Image("musicnote")
                                                        .resizable()
                                                        .interpolation(.high)
                                                        .scaledToFit()
                                                        .frame(width: isPlaying ? size.width : 250, height: isPlaying ? size.height : 250)
                                                        .clipShape(RoundedRectangle(cornerRadius: animateContent ? 15 : 5, style: .continuous))
                                                        .animation(.easeInOut(duration: 0.3), value: isPlaying) // Add animation for smooth expand
                                                }
                                            }
                                        )
                                        .onAppear {
                                            self.fetchAudio()
                                        }
                                    }
                                } else if activeTab == .video {
                                    VideoPlayer(player: player)
                                        .onAppear {
                                            self.fetchVideo()
                                        }
                                        .allowsHitTesting(false)
                                        .opacity(animateContent ? 1 : 0)
                                        .frame(width: isPlaying ? size.width : 250, height: isPlaying ? size.height : 250)
                                        .clipShape(RoundedRectangle(cornerRadius: animateContent ? 15 : 5, style: .continuous))
                                        .animation(.easeInOut(duration: 0.3), value: isPlaying)
                                }
                            }
                            .matchedGeometryEffect(id: "Album Cover", in: animation, isSource: false)
                            .offset(x: isPlaying ? 0 : 47, y: isPlaying ? 0 : 47)
                            .frame(height: size.width - 50)
                            .padding(.vertical, size.height < 700 ? 10 : 15)
                            .padding(.top, 3)
                            
                            playerButtons(size: size)
                                .offset(y: animateContent ? 0 : size.height)
                        }
                    } else if activePage == .lyrics {
                        VStack {
                            Capsule()
                                .fill(.gray)
                                .frame(width: 40, height: 5)
                                .toolbarBackground(.hidden, for: .navigationBar)
                                .opacity(animateContent ? 1 : 0)
                                .offset(y: animateContent ? 0 : size.height)
                            
                            HStack {
                                GeometryReader {
                                    let size = $0.size
                                    
                                    AnyView(
                                        WebImage(url: URL(string: viewModel.thumbnailURL ?? "musicnote")) { phase in
                                            switch phase {
                                            case .success(let image):
                                                image.resizable()
                                                    .scaledToFit()
                                                    .frame(width: 80, height: 80)
                                                    .cornerRadius(5)
                                                    .animation(.easeInOut(duration: 0.3), value: isPlaying) // Add animation for smooth expand
                                            case .failure, .empty:
                                                Image("musicnote")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 80, height: 80)
                                                    .cornerRadius(5)
                                                    .animation(.easeInOut(duration: 0.3), value: isPlaying) // Add animation for smooth expand
                                            }
                                        }
                                    )
                                }
                                .frame(width: 80, height: 80)
                                .matchedGeometryEffect(id: "Album Cover", in: animation, isSource: false)
                                
                                HStack(alignment: .center, spacing: 15) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(viewModel.title ?? "Not Playing")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                        
                                        Text(viewModel.artistName ?? "Artist")
                                            .foregroundColor(.white.opacity(0.6))
                                            .blendMode(.overlay)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    Button {
                                        liked.toggle()
                                    } label: {
                                        Image(liked ? "liked" : "unliked")
                                            .foregroundColor(.white)
                                            .font(.title)
                                    }
                                    
                                    Menu {
                                        Button(action: {
                                            // Action for Add to Playlist button
                                        }) {
                                            Label("Add to Playlist", systemImage: "plus")
                                        }
                                        
                                        Button(action: {
                                            // Action for Downloading Song
                                        }) {
                                            Label("Download", systemImage: "arrow.down.circle")
                                        }
                                        
                                        Button(action: {
                                            // Action for Sharing the Song
                                        }) {
                                            Label("Share", systemImage: "square.and.arrow.up")
                                        }
                                    } label: {
                                        Label ("", systemImage: "ellipsis")
                                            .font(.system(size: 21))
                                            .foregroundColor(.white)
                                            .padding(.vertical, 12)
                                            .padding(.bottom, 8)
                                            .padding(.leading, 12)
                                            .padding(.trailing, -9)
                                    }
                                }
                            }
                        }
                        
                        RoundedRectangle(cornerRadius: 15)
                            .frame(width: 343, height: 343)
                        
                        altButtons(size: size)
                    } else if activePage == .queue {
                        VStack {
                            Capsule()
                                .fill(.gray)
                                .frame(width: 40, height: 5)
                                .toolbarBackground(.hidden, for: .navigationBar)
                                .opacity(animateContent ? 1 : 0)
                                .offset(y: animateContent ? 0 : size.height)
                            
                            HStack {
                                GeometryReader {
                                    let size = $0.size
                                    
                                    AnyView(
                                        WebImage(url: URL(string: viewModel.thumbnailURL ?? "musicnote")) { phase in
                                            switch phase {
                                            case .success(let image):
                                                image.resizable()
                                                    .scaledToFit()
                                                    .frame(width: 80, height: 80)
                                                    .cornerRadius(5)
                                                    .animation(.easeInOut(duration: 0.3), value: isPlaying) // Add animation for smooth expand
                                            case .failure, .empty:
                                                Image("musicnote")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 80, height: 80)
                                                    .cornerRadius(5)
                                                    .animation(.easeInOut(duration: 0.3), value: isPlaying) // Add animation for smooth expand
                                            }
                                        }
                                    )
                                }
                                .frame(width: 80, height: 80)
                                .matchedGeometryEffect(id: "Album Cover", in: animation, isSource: false)
                                
                                HStack(alignment: .center, spacing: 15) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(viewModel.title ?? "Not Playing")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                        
                                        Text(viewModel.artistName ?? "Artist")
                                            .foregroundColor(.white.opacity(0.6))
                                            .blendMode(.overlay)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    Button {
                                        liked.toggle()
                                    } label: {
                                        Image(liked ? "liked" : "unliked")
                                            .foregroundColor(.white)
                                            .font(.title)
                                    }
                                    
                                    Menu {
                                        Button(action: {
                                            // Action for Add to Playlist button
                                        }) {
                                            Label("Add to Playlist", systemImage: "plus")
                                        }
                                        
                                        Button(action: {
                                            // Action for Downloading Song
                                        }) {
                                            Label("Download", systemImage: "arrow.down.circle")
                                        }
                                        
                                        Button(action: {
                                            // Action for Sharing the Song
                                        }) {
                                            Label("Share", systemImage: "square.and.arrow.up")
                                        }
                                    } label: {
                                        Label ("", systemImage: "ellipsis")
                                            .font(.system(size: 21))
                                            .foregroundColor(.white)
                                            .padding(.vertical, 12)
                                            .padding(.bottom, 8)
                                            .padding(.leading, 12)
                                            .padding(.trailing, -9)
                                    }
                                }
                            }
                        }
                        
                        RoundedRectangle(cornerRadius: 15)
                            .frame(width: 343, height: 343)
                        
                        altButtons(size: size)
                    }
                }
                .padding(.top, safeArea.top + (safeArea.bottom == 0 ? 10 : 0))
                .padding(.bottom, safeArea.bottom == 0 ? 10 : safeArea.bottom)
                .padding(.horizontal, 25)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .clipped()
            }
            .contentShape(Rectangle())
            .offset(y: offsetY)
            .gesture(dragGesture(size: size))
            .ignoresSafeArea(.container, edges: .all)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.35)) {
                    animateContent = true
                }
            }
        }
    }
    
    func dynamicBackground() -> some View {
        GeometryReader { geometry in
            AnyView(
                WebImage(url: URL(string: viewModel.thumbnailURL ?? "musicnote")) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable()
                            .interpolation(.high)
                            .scaledToFill()
                            .frame(width: UIScreen.main.bounds.size.width, height: UIScreen.main.bounds.size.height) // Adjusted frame size to fill screen
                            .ignoresSafeArea(edges: .all)
                            .clipShape(RoundedRectangle(cornerRadius: animateContent ? deviceCornerRadius : 0, style: .continuous))
                            .overlay(content: {
                                RoundedRectangle(cornerRadius: animateContent ? deviceCornerRadius : 0, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                    .opacity(animateContent ? 1 : 0)
                            })
                    case .failure, .empty:
                        Image("musicnote")
                            .resizable()
                            .interpolation(.high)
                            .edgesIgnoringSafeArea(.all)
                            .scaledToFill()
                            .frame(width: UIScreen.main.bounds.size.width, height: UIScreen.main.bounds.size.height) // Adjusted frame size to fill screen
                            .clipShape(RoundedRectangle(cornerRadius: animateContent ? deviceCornerRadius : 0, style: .continuous))
                            .overlay(content: {
                                RoundedRectangle(cornerRadius: animateContent ? deviceCornerRadius : 0, style: .continuous)
                                    .fill(.bg)
                                    .opacity(animateContent ? 1 : 0)
                            })
                    }
                }
            )
        }
        .overlay(alignment: .top) {
            MusicInfo(title: viewModel.title ?? "Not Playing", artistName: viewModel.artistName ?? "", thumbnailURL: viewModel.thumbnailURL ?? "musicnote", animation: animation, expandPlayer: $expandPlayer)
                .allowsHitTesting(false)
                .opacity(animateContent ? 0 : 1)
        }
        .matchedGeometryEffect(id: "Background", in: animation)
    }
    
    
    private func fetchAudio() {
        Task {
            do {
                let streams = try await self.loadStreams()
                guard let availableStream = streams.last(where: { $0.includesAudioTrack && !$0.includesVideoTrack }) else {
                    return
                }
                let playerItem = AVPlayerItem(url: availableStream.url)
                self.player.replaceCurrentItem(with: playerItem)
                self.player.play()
            } catch let error {
                print("Error: \(error)")
            }
        }
    }
    
    private func fetchVideo()  {
        Task {
            do {
                let streams = try await self.loadStreams()
                guard let availableStream = streams.last(where: { $0.includesVideoAndAudioTrack && $0.isNativelyPlayable }) else {
                    return
                }
                let playerItem = AVPlayerItem(url: availableStream.url)
                self.player.replaceCurrentItem(with: playerItem)
                self.player.play()
            } catch let error {
                print("Error: \(error)")
            }
        }
    }
    
    private func loadStreams() async throws -> [YouTubeResponder.Stream] {
        
        let videos = try await self.fetchYouTubeVideos()
        guard let video = videos.items.first else {
            throw NSError(domain: "Unable to match media.", code: -1)
        }
        let streams = try await YouTubeResponder.YouTube(videoID: viewModel.videoID ?? video.id).streams
        return streams
    }
    
    private func fetchYouTubeVideos() async throws -> YouTubeResponder.SearchResults {
        let searchResults = try await YouTubeResponder.YouTubeSearch.results(keyword: keyword)
        return searchResults
    }
    
    private func altButtons(size: CGSize) -> some View {
        VStack(spacing: size.height * 0.04) {
            GeometryReader {
                let size = $0.size
                let spacing = size.height * 0.04
                
                VStack(spacing: spacing) {
                    VStack(spacing: spacing) {
                        //Song Duration Slider
                        MusicProgressSlider(
                            value: $currentTime,
                            inRange: 0...maxDuration,
                            activeFillColor: color,
                            fillColor: normalFillColor,
                            emptyColor: emptyColor,
                            height: 32,
                            onEditingChanged: { editing in
                                // Handle editing changed
                            },
                            player: player // Pass AVPlayer instance
                        )
                        .padding(.top, spacing)
                    }
                    .frame(height: size.height / 2.5, alignment: .top)
                    
                    //MARK: Playback Controls
                    HStack(spacing: size.width * 0.18) {
                        BackwardButton()
                        
                        Button {
                            if isPlaying == false {
                                player.play()
                            } else if isPlaying == true {
                                player.pause()
                            }
                            isPlaying.toggle()
                            transparency = 0.6
                            withAnimation(.easeOut(duration: 0.2)) {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    transparency = 0.0
                                }
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .frame(width: 80, height: 80)
                                    .opacity(transparency)
                                Image(systemName: "pause.fill")
                                    .font(.system(size: 50))
                                    .scaleEffect(isPlaying ? 1 : 0)
                                    .opacity(isPlaying ? 1 : 0)
                                    .animation(.interpolatingSpring(stiffness: 170, damping: 15), value: isPlaying)
                                Image(systemName: "play.fill")
                                    .font(.system(size: 50))
                                    .scaleEffect(isPlaying ? 0 : 1)
                                    .opacity(isPlaying ? 0 : 1)
                                    .animation(.interpolatingSpring(stiffness: 170, damping: 15), value: isPlaying)
                            }
                        }
                        .padding(.horizontal, -25)
                        ForwardButton()
                    }
                    .padding(.top, -50)
                    .foregroundColor(.white)
                    .frame(maxHeight: .infinity)
                    
                    //MARK: Volume Controls
                    VStack(spacing: spacing) {
                        VolumeSlider(value: $volume, inRange: 0...maxVolume, activeFillColor: color, fillColor: normalFillColor, emptyColor: emptyColor, height: 8) { started in }
                        
                        HStack(alignment: .top, spacing: (UIScreen.main.bounds.width - 200) / 4) {
                            Button(action: {
                                if activePage == .player {
                                    activePage = .lyrics
                                } else if activePage == .lyrics {
                                    activePage = .player
                                } else if activePage == .queue {
                                    activePage = .lyrics
                                }
                            }) {
                                Image(systemName: "quote.bubble")
                                    .font(.title2)
                            }
                            .padding(.top, 2.5)
                            
                            Button {
                                isCommenting = true
                            } label: {
                                Image(systemName: "text.bubble")
                                .font(.title2)
                            }
                            .sheet(isPresented: $isCommenting, content: {
                                Comments()
                            })
                            .padding(.top, 2.5)
                            
                            AirPlayButton()
                                .frame(width: 50, height: 50)
                                .padding(.top, -10)
                            
                            Button(action: {
                                if activePage == .player {
                                    activePage = .queue
                                } else if activePage == .queue {
                                    activePage = .player
                                } else if activePage == .lyrics {
                                    activePage = .queue
                                }
                            }) {
                                Image(systemName: "list.bullet")
                                    .font(.title2)
                            }
                            .padding(.top, 5)
                        }
                        .foregroundColor(.white)
                        .blendMode(.overlay)
                        .padding(.top, spacing)
                    }
                    .padding(.bottom, 30)
                    .frame(height: size.height / 2.5, alignment: .bottom)
                }
            }
        }
        .padding(.top, 20)
    }
    
    private func playerButtons(size: CGSize) -> some View {
        VStack(spacing: size.height * 0.04) {
            GeometryReader {
                let size = $0.size
                let spacing = size.height * 0.04
                
                VStack(spacing: spacing) {
                    VStack(spacing: spacing) {
                        HStack(alignment: .center, spacing: 15) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(viewModel.title ?? "Not Playing")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                
                                Text(viewModel.artistName ?? "Artist")
                                    .foregroundColor(.white.opacity(0.6))
                                    .blendMode(.overlay)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Button {
                                liked.toggle()
                            } label: {
                                Image(liked ? "liked" : "unliked")
                                    .foregroundColor(.white)
                                    .font(.title)
                            }
                            
                            Menu {
                                Button(action: {
                                    // Action for Add to Playlist button
                                }) {
                                    Label("Add to Playlist", systemImage: "plus")
                                }
                                
                                Button(action: {
                                    // Action for Downloading Song
                                }) {
                                    Label("Download", systemImage: "arrow.down.circle")
                                }
                                
                                Button(action: {
                                    // Action for Sharing the Song
                                }) {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                }
                            } label: {
                                Label ("", systemImage: "ellipsis")
                                    .font(.system(size: 21))
                                    .foregroundColor(.white)
                                    .padding(.vertical, 12)
                                    .padding(.bottom, 8)
                                    .padding(.leading, 12)
                                    .padding(.trailing, -9)
                            }
                        }
                        
                        //Song Duration Slider
                        MusicProgressSlider(
                            value: $currentTime,
                            inRange: 0...maxDuration,
                            activeFillColor: color,
                            fillColor: normalFillColor,
                            emptyColor: emptyColor,
                            height: 32,
                            onEditingChanged: { editing in
                                // Handle editing changed
                            },
                            player: player // Pass AVPlayer instance
                        )
                        .padding(.top, spacing)
                    }
                    .frame(height: size.height / 2.5, alignment: .top)
                    
                    //MARK: Playback Controls
                    HStack(spacing: size.width * 0.18) {
                        BackwardButton()
                        
                        Button {
                            if isPlaying == false {
                                player.play()
                            } else if isPlaying == true {
                                player.pause()
                            }
                            isPlaying.toggle()
                            transparency = 0.6
                            withAnimation(.easeOut(duration: 0.2)) {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    transparency = 0.0
                                }
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .frame(width: 80, height: 80)
                                    .opacity(transparency)
                                Image(systemName: "pause.fill")
                                    .font(.system(size: 50))
                                    .scaleEffect(isPlaying ? 1 : 0)
                                    .opacity(isPlaying ? 1 : 0)
                                    .animation(.interpolatingSpring(stiffness: 170, damping: 15), value: isPlaying)
                                Image(systemName: "play.fill")
                                    .font(.system(size: 50))
                                    .scaleEffect(isPlaying ? 0 : 1)
                                    .opacity(isPlaying ? 0 : 1)
                                    .animation(.interpolatingSpring(stiffness: 170, damping: 15), value: isPlaying)
                            }
                        }
                        .padding(.horizontal, -25)
                        ForwardButton()
                    }
                    .padding(.top, -15)
                    .foregroundColor(.white)
                    .frame(maxHeight: .infinity)
                    
                    //MARK: Volume Controls
                    VStack(spacing: spacing) {
                        VolumeSlider(value: $volume, inRange: 0...maxVolume, activeFillColor: color, fillColor: normalFillColor, emptyColor: emptyColor, height: 8) { started in }
                        
                        HStack(alignment: .top, spacing: (UIScreen.main.bounds.width - 200) / 4) {
                            Button(action: {
                                if activePage == .player {
                                    activePage = .lyrics
                                } else if activePage == .lyrics {
                                    activePage = .player
                                } else if activePage == .queue {
                                    activePage = .lyrics
                                }
                            }) {
                                Image(systemName: "quote.bubble")
                                    .font(.title2)
                            }
                            .padding(.top, 2.5)
                            
                            Button {
                                isCommenting = true
                            } label: {
                                Image(systemName: "text.bubble")
                                .font(.title2)
                            }
                            .sheet(isPresented: $isCommenting, content: {
                                Comments()
                            })
                            .padding(.top, 2.5)
                            
                            AirPlayButton()
                                .frame(width: 50, height: 50)
                                .padding(.top, -10)
                            
                            Button(action: {
                                if activePage == .player {
                                    activePage = .queue
                                } else if activePage == .queue {
                                    activePage = .player
                                } else if activePage == .lyrics {
                                    activePage = .queue
                                }
                            }) {
                                Image(systemName: "list.bullet")
                                    .font(.title2)
                            }
                            .padding(.top, 5)
                        }
                        .foregroundColor(.white)
                        .blendMode(.overlay)
                        .padding(.top, spacing)
                    }
                    .padding(.bottom, 30)
                    .frame(height: size.height / 2.5, alignment: .bottom)
                }
            }
        }
    }
    
    private func dragGesture(size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                // Calculate the translation along the Y-axis
                let translationY = value.translation.height
                // Limit the upward translation
                offsetY = (translationY > 0 ? translationY : 0)
            }
            .onEnded { value in
                // Use a smooth easing function and adjust the duration for a better transition
                withAnimation(.easeInOut(duration: 0.3)) {
                    if offsetY > size.height * 0.3 {
                        // Collapse the player
                        expandPlayer = false
                        animateContent = false
                        offsetY = 0 // Reset the offset
                    } else {
                        // Return the player to its original position
                        offsetY = 0
                    }
                }
            }
    }
}

enum pql: String, CaseIterable {
    case player = "play.fill"
    case queue = "quote.bubble"
    case lyrics = "list.bullet"
}
