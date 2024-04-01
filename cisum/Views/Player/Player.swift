//
//  Player.swift
//  cisum
//
//  Created by Aarav Gupta on 09/03/24.
//

import SwiftUI
import WebKit

struct Player: View {
    //Player thingy
    var videoID: String
    
    //Accent Color
    let AccentColor = Color(red : 0.9764705882352941, green: 0.17647058823529413, blue: 0.2823529411764706, opacity: 0.3)
    
    //View Properties
    @State private var activeTab: songorvideo = .song
    @Binding var expandPlayer: Bool
    var animation: Namespace.ID
    @State private var animateContent: Bool = false
    @State private var offsetY: CGFloat = 0
    @State private var liked: Bool = false
    @State private var isPlaying: Bool = false
    @State private var transparency: Double = 0.0
    var body: some View {
        GeometryReader {
            let size = $0.size
            let safeArea = $0.safeAreaInsets
            
            ZStack {
                RoundedRectangle(cornerRadius: animateContent ? deviceCornerRadius : 0, style: .continuous)
                    .fill(.ultraThickMaterial)
                    .overlay(content: {
                        RoundedRectangle(cornerRadius: animateContent ? deviceCornerRadius : 0, style: .continuous)
                            .fill(.ultraThickMaterial)
                            .opacity(animateContent ? 1 : 0)
                    })
                    .overlay(alignment: .top) {
                        MusicInfo(expandPlayer: $expandPlayer, animation: animation)
                            .allowsHitTesting(false)
                            .opacity(animateContent ? 0 : 1)
                    }
                    .matchedGeometryEffect(id: "Background", in: animation)
                
                VStack(spacing: 15) {
                    //Song/Video
                    VStack(spacing: 15) {
                        SongOrVideo(tabs: songorvideo.allCases, activeTab: $activeTab, height: 35, font: .body, activeTint: .primary, inActiveTint: .gray.opacity(0.5)) { size in
                            RoundedRectangle(cornerRadius: 30)
                                .fill(AccentColor)
                                .frame(height: size.height)
                                .frame(maxHeight: .infinity, alignment: .bottom)
                        }
                        .background {
                            RoundedRectangle(cornerRadius: 30)
                                .fill(.ultraThinMaterial)
                                .ignoresSafeArea()
                        }
                        .padding(.horizontal, 15)
                        
                        Spacer(minLength: 0)
                    }
                    .frame(width: 210, height: 35)
                    .padding(.vertical, 15)
                    .toolbarBackground(.hidden, for: .navigationBar)
                    .opacity(animateContent ? 1 : 0)
                    //Fixing Slide Animation
                    .offset(y: animateContent ? 0 : size.height)
                    
                    //MARK: Async Artwork
                    GeometryReader {
                        let size = $0.size
                        
                        APIPlayer(videoID: videoID)
                            .frame(width: isPlaying ? 343 : 250, height: isPlaying ? 343 : 250)
                            .clipShape(RoundedRectangle(cornerRadius: animateContent ? 15 : 5, style: .continuous))
                    }
                    .matchedGeometryEffect(id: "Album Cover", in: animation)
                    //Square Artwork Image
                    .offset(x: isPlaying ? 0 : 47, y: isPlaying ? 0 : 47)
                    .frame(width: 343, height: 343)
                    .padding(.top, -25)
                    .padding(.vertical, size.height < 700 ? 10 : 15)
                    
                    //Player Sliders
                    PlayerButtons(size: size)
                        .offset(y: animateContent ? 0 : size.height)
                }
                .padding(.top, safeArea.top + (safeArea.bottom == 0 ? 10 : 0))
                .padding(.bottom, safeArea.bottom == 0 ? 10 : safeArea.bottom)
                .padding(.horizontal, 25)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .clipped()
            }
            .contentShape(Rectangle())
            .offset(y: offsetY)
            .gesture(
                DragGesture()
                    .onChanged({ value in
                        let translationY = value.translation.height
                        offsetY = (translationY > 0 ? translationY : 0)
                    })
                    .onEnded({ value in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            if offsetY > size.height * 0.4 {
                                expandPlayer = false
                                animateContent = false
                            } else {
                                offsetY = .zero
                            }
                        }
                    })
            )
            .ignoresSafeArea(.container, edges: .all)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.35)) {
                animateContent = true
            }
        }
    }
    
    @ViewBuilder
    func PlayerButtons(size: CGSize) -> some View {
        GeometryReader {
            let size = $0.size
            let spacing = size.height * 0.04
            
            VStack(spacing: spacing) {
                VStack(spacing: spacing) {
                    HStack(alignment: .center, spacing: 15) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Song Name")
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            Text("Artist")
                                .foregroundColor(.gray)
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
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(12)
                                .padding(.leading, 12)
                        }
                    }
                    
                    //Song Duration Slider
                    Capsule()
                        .fill(.gray)
                        .frame(height: 8)
                        .padding(.top, spacing)
                    
                    //Song Duration Label
                    HStack {
                        Text("--:--")
                            .font(.caption)
                        
                        Spacer(minLength: 0)
                        
                        Text("--:--")
                            .font(.caption)
                    }
                    .foregroundColor(.gray)
                }
                .frame(height: size.height / 2.5, alignment: .top)
                
                //MARK: Playback Controls
                HStack(spacing: size.width * 0.18) {
                    BackwardButton()
                    
                    Button {
                        //Play/Pause Function
                        
                        
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
                    
                    ForwardButton()
                }
                .padding(.top, -15)
                .foregroundColor(.white)
                .frame(maxHeight: .infinity)
                
                //MARK: Volume Controls
                VStack(spacing: spacing) {
                    HStack(spacing: 15) {
                        Image(systemName: "speaker.fill")
                            .foregroundColor(.gray)
                        
                        Capsule()
                            .fill(.gray)
                            .environment(\.colorScheme, .light)
                            .frame(height: 8)
                        
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundColor(.gray)
                    }
                    
                    HStack(alignment: .top, spacing: size.width * 0.18) {
                        Button(action: {
                            
                        }) {
                            Image(systemName: "quote.bubble")
                                .font(.title2)
                        }
                        .padding(.top, 3)
                        
                        AirPlayButton()
                            .frame(width: 50, height: 50)
                            .padding(.top, -13)
                            .padding(.horizontal, 25)
                        
                        NavigationView {
                            VStack {
                                NavigationLink { UpNext(expandPlayer: $expandPlayer, animation: animation)
                                } label: {
                                    Image(systemName: "list.bullet")
                                        .font(.title2)
                                }
                            }
                        }
                        .padding(.top, 3)
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

extension View {
  var deviceCornerRadius: CGFloat {
    let key = "_displayCornerRadius"
    if let screen = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.screen {
      if let cornerRadius = screen.value(forKey: key) as? CGFloat {
        return cornerRadius
      }

      return 0
    }

    return 0
  }
}

//import SwiftUI
//import WebKit
//
//struct Player: View {
//    //Player thingy
//    var videoID: String
//    
//    //Accent Color
//    let AccentColor = Color(red : 0.9764705882352941, green: 0.17647058823529413, blue: 0.2823529411764706, opacity: 0.3)
//    
//    //View Properties
//    @State private var activeTab: songorvideo = .song
//    @Binding var expandPlayer: Bool
//    var animation: Namespace.ID
//    @State private var animateContent: Bool = false
//    @State private var offsetY: CGFloat = 0
//    @State private var liked: Bool = false
//    @State private var isPlaying: Bool = false
//    @State private var transparency: Double = 0.0
//    var body: some View {
//        GeometryReader {
//            let size = $0.size
//            let safeArea = $0.safeAreaInsets
//            
//            ZStack {
//                RoundedRectangle(cornerRadius: animateContent ? deviceCornerRadius : 0, style: .continuous)
//                    .fill(.ultraThickMaterial)
//                    .overlay(content: {
//                        RoundedRectangle(cornerRadius: animateContent ? deviceCornerRadius : 0, style: .continuous)
//                            .fill(.ultraThickMaterial)
//                            .opacity(animateContent ? 1 : 0)
//                    })
//                    .overlay(alignment: .top) {
//                        MusicInfo(expandPlayer: $expandPlayer, animation: animation)
//                            .allowsHitTesting(false)
//                            .opacity(animateContent ? 0 : 1)
//                    }
//                    .matchedGeometryEffect(id: "Background", in: animation)
//                
//                VStack(spacing: 15) {
//                    //Song/Video
//                    VStack(spacing: 15) {
//                        SongOrVideo(tabs: songorvideo.allCases, activeTab: $activeTab, height: 35, font: .body, activeTint: .primary, inActiveTint: .gray.opacity(0.5)) { size in
//                            RoundedRectangle(cornerRadius: 30)
//                                .fill(AccentColor)
//                                .frame(height: size.height)
//                                .frame(maxHeight: .infinity, alignment: .bottom)
//                        }
//                        .background {
//                            RoundedRectangle(cornerRadius: 30)
//                                .fill(.ultraThinMaterial)
//                                .ignoresSafeArea()
//                        }
//                        .padding(.horizontal, 15)
//                        
//                        Spacer(minLength: 0)
//                    }
//                    .frame(width: 210, height: 35)
//                    .padding(.vertical, 15)
//                    .toolbarBackground(.hidden, for: .navigationBar)
//                    .opacity(animateContent ? 1 : 0)
//                    //Fixing Slide Animation
//                    .offset(y: animateContent ? 0 : size.height)
//                    
//                    //MARK: Async Artwork
//                    GeometryReader {
//                        let size = $0.size
//                        
//                        Image("Image")
//                            .resizable()
//                            .aspectRatio(contentMode: .fill)
//                            .frame(width: 80, height: 80)
//                            .clipShape(RoundedRectangle(cornerRadius: animateContent ? 5 : 5, style: .continuous))
//                        
////                        PipedPlayer(videoID: videoID)
////                            .frame(width: isPlaying ? size.width : 250, height: isPlaying ? size.height : 250)
////                            .clipShape(RoundedRectangle(cornerRadius: animateContent ? 15 : 5, style: .continuous))
//                    }
//                    .matchedGeometryEffect(id: "Album Cover", in: animation)
//                    //Square Artwork Image
//                    .offset(x: isPlaying ? 0 : 47, y: isPlaying ? 0 : 47)
//                    .frame(width: 343, height: 343)
//                    .padding(.top, -25)
//                    .padding(.vertical, size.height < 700 ? 10 : 15)
//                    
//                    //Player Sliders
//                    PlayerButtons(size: size)
//                        .offset(y: animateContent ? 0 : size.height)
//                }
//                .padding(.top, safeArea.top + (safeArea.bottom == 0 ? 10 : 0))
//                .padding(.bottom, safeArea.bottom == 0 ? 10 : safeArea.bottom)
//                .padding(.horizontal, 25)
//                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
//                .clipped()
//            }
//            .contentShape(Rectangle())
//            .offset(y: offsetY)
//            .gesture(
//                DragGesture()
//                    .onChanged({ value in
//                        let translationY = value.translation.height
//                        offsetY = (translationY > 0 ? translationY : 0)
//                    })
//                    .onEnded({ value in
//                        withAnimation(.easeInOut(duration: 0.3)) {
//                            if offsetY > size.height * 0.4 {
//                                expandPlayer = false
//                                animateContent = false
//                            } else {
//                                offsetY = .zero
//                            }
//                        }
//                    })
//            )
//            .ignoresSafeArea(.container, edges: .all)
//        }
//        .onAppear {
//            withAnimation(.easeInOut(duration: 0.35)) {
//                animateContent = true
//            }
//        }
//    }
//    
//    @ViewBuilder
//    func PlayerButtons(size: CGSize) -> some View {
//        GeometryReader {
//            let size = $0.size
//            let spacing = size.height * 0.04
//            
//            VStack(spacing: spacing) {
//                VStack(spacing: spacing) {
//                    HStack(alignment: .center, spacing: 15) {
//                        VStack(alignment: .leading, spacing: 4) {
//                            Text("Song Name")
//                                .font(.title3)
//                                .fontWeight(.semibold)
//                            
//                            Text("Artist")
//                                .foregroundColor(.gray)
//                        }
//                        .frame(maxWidth: .infinity, alignment: .leading)
//                        
//                        Button {
//                            liked.toggle()
//                        } label: {
//                            Image(liked ? "liked" : "unliked")
//                                .foregroundColor(.white)
//                                .font(.title)
//                        }
//                        
//                        Menu {
//                            Button(action: {
//                                // Action for Add to Playlist button
//                            }) {
//                                Label("Add to Playlist", systemImage: "plus")
//                            }
//                            
//                            Button(action: {
//                                // Action for Downloading Song
//                            }) {
//                                Label("Download", systemImage: "arrow.down.circle")
//                            }
//                            
//                            Button(action: {
//                                // Action for Sharing the Song
//                            }) {
//                                Label("Share", systemImage: "square.and.arrow.up")
//                            }
//                        } label: {
//                            Label ("", systemImage: "ellipsis")
//                                .font(.title2)
//                                .foregroundColor(.white)
//                                .padding(12)
//                                .padding(.leading, 12)
//                        }
//                    }
//                    
//                    //Song Duration Slider
//                    Capsule()
//                        .fill(.gray)
//                        .frame(height: 8)
//                        .padding(.top, spacing)
//                    
//                    //Song Duration Label
//                    HStack {
//                        Text("--:--")
//                            .font(.caption)
//                        
//                        Spacer(minLength: 0)
//                        
//                        Text("--:--")
//                            .font(.caption)
//                    }
//                    .foregroundColor(.gray)
//                }
//                .frame(height: size.height / 2.5, alignment: .top)
//                
//                //MARK: Playback Controls
//                HStack(spacing: size.width * 0.18) {
//                    BackwardButton()
//                    
//                    Button {
//                        //Play/Pause Function
//                        
//                        
//                        isPlaying.toggle()
//                        transparency = 0.6
//                        withAnimation(.easeOut(duration: 0.2)) {
//                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
//                                transparency = 0.0
//                            }
//                        }
//                    } label: {
//                        ZStack {
//                            Circle()
//                                .frame(width: 80, height: 80)
//                                .opacity(transparency)
//                            Image(systemName: "pause.fill")
//                                .font(.system(size: 50))
//                                .scaleEffect(isPlaying ? 1 : 0)
//                                .opacity(isPlaying ? 1 : 0)
//                                .animation(.interpolatingSpring(stiffness: 170, damping: 15), value: isPlaying)
//                            
//                            Image(systemName: "play.fill")
//                                .font(.system(size: 50))
//                                .scaleEffect(isPlaying ? 0 : 1)
//                                .opacity(isPlaying ? 0 : 1)
//                                .animation(.interpolatingSpring(stiffness: 170, damping: 15), value: isPlaying)
//                        }
//                    }
//                    
//                    ForwardButton()
//                }
//                .padding(.top, -15)
//                .foregroundColor(.white)
//                .frame(maxHeight: .infinity)
//                
//                //MARK: Volume Controls
//                VStack(spacing: spacing) {
//                    HStack(spacing: 15) {
//                        Image(systemName: "speaker.fill")
//                            .foregroundColor(.gray)
//                        
//                        Capsule()
//                            .fill(.gray)
//                            .environment(\.colorScheme, .light)
//                            .frame(height: 8)
//                        
//                        Image(systemName: "speaker.wave.3.fill")
//                            .foregroundColor(.gray)
//                    }
//                    
//                    HStack(alignment: .top, spacing: size.width * 0.18) {
//                        NavigationStack {
//                            NavigationLink(destination: Lyrics(expandPlayer: $expandPlayer, animation: animation)) { Image(systemName: "list.bullet")
//                                    .font(.title2)
//                            }
//                        }
//                        .padding(.top, 3)
//                        
//                        AirPlayButton()
//                            .frame(width: 50, height: 50)
//                            .padding(.top, -13)
//                            .padding(.horizontal, 25)
//                        
//                        NavigationStack {
//                            NavigationLink(destination: UpNext(expandPlayer: $expandPlayer, animation: animation)) { Image(systemName: "list.bullet")
//                                    .font(.title2)
//                            }
//                        }
//                        .padding(.top, 3)
//                    }
//                    .foregroundColor(.white)
//                    .blendMode(.overlay)
//                    .padding(.top, spacing)
//                }
//                .padding(.bottom, 30)
//                .frame(height: size.height / 2.5, alignment: .bottom)
//            }
//        }
//    }
//}
//
//extension View {
//  var deviceCornerRadius: CGFloat {
//    let key = "_displayCornerRadius"
//    if let screen = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.screen {
//      if let cornerRadius = screen.value(forKey: key) as? CGFloat {
//        return cornerRadius
//      }
//
//      return 0
//    }
//
//    return 0
//  }
//}

#Preview {
    Main(videoID: "")
    .preferredColorScheme(.dark)
}
