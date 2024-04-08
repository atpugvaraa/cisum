////
////  UpNext.swift
////  cisum
////
////  Created by Aarav Gupta on 09/03/24.
////
//
import SwiftUI

struct UpNext: View {
    let AccentColor = Color(red : 0.9764705882352941, green: 0.17647058823529413, blue: 0.2823529411764706, opacity: 0.3)
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
                    Capsule()
                        .frame(width: 40, height: 5)
                        .padding(.vertical, 15)
                        .toolbarBackground(.hidden, for: .navigationBar)
                        .opacity(animateContent ? 1 : 0)
                    //Fixing Slide Animation
                        .offset(y: animateContent ? 0 : size.height)
                    
                    HStack {
                        //Artwork
                        GeometryReader {
                            let size = $0.size
                            
                            Image("Image")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: animateContent ? 5 : 5, style: .continuous))
                        }
                        .matchedGeometryEffect(id: "Album Cover", in: animation)
                        //Square Artwork Image
                        .frame(width: 80, height: 80)
                        .padding(.top, -25)
                        .padding(.vertical, size.height < 700 ? 10 : 15)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Song Name")
                                .font(.title3)
                                .fontWeight(.semibold)

                            Text("Artist")
                                .foregroundColor(.gray)
                        }
                        .padding(.top, -15)
                        .frame(maxWidth: .infinity, alignment: .center)
                        
                        Button {
                            liked.toggle()
                        } label: {
                            Image(liked ? "liked" : "unliked")
                                .foregroundColor(.white)
                                .font(.title)
                        }
                        .padding(.top, -30)
                        
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
                                .padding(.bottom, 40)
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(12)
                                .padding(.leading, 12)
                        }
                    }
                        //Player Sliders
                        PlayerButtons(size: size)
                            .offset(y: animateContent ? 0 : size.height)
                }
                .offset(y: animateContent ? 0 : size.height)
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
    
    struct upnextQueue: View {
        var body: some View {
            VStack {
                Image("Image")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
            .frame(width: 343, height: 343)
        }
    }
    
    @ViewBuilder
    func PlayerButtons(size: CGSize) -> some View {
        GeometryReader {
            let size = $0.size
            let spacing = size.height * 0.04
            
            VStack(spacing: spacing) {
                upnextQueue()
                VStack(spacing: spacing) {
                    
                    //Song Duration Slider
                    Capsule()
                        .fill(.gray)
                        .frame(height: 8)
                    
                    //Song Duration Label
                    HStack {
                        Text("--:--")
                            .font(.caption)
                        
                        Spacer(minLength: 0)
                        
                        Text("--:--")
                            .font(.caption)
                    }
                    .padding(.top, -10)
                    .foregroundColor(.gray)
                }
                
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
                .padding(.top, -18)
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
                        Button {
                            
                        } label: {
                            Image(systemName: "quote.bubble")
                                .font(.title2)
                        }
                        
                        AirPlayButton()
                            .frame(width: 50, height: 50)
                            .padding(.top, -13)
                        .padding(.horizontal, 25)
                        
                        Button {
                            
                        } label: {
                            Image(systemName: "list.bullet")
                                .font(.title2)
                        }
                        .padding(.top, 3)
                    }
                    .foregroundColor(.white)
                    .blendMode(.overlay)
                }
                .padding(.bottom, 10)
            }
        }
    }
}

#Preview {
    Main(videoID: "")
}

//struct UpNext: View {
//    let AccentColor = Color(red : 0.9764705882352941, green: 0.17647058823529413, blue: 0.2823529411764706, opacity: 0.3)
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
//                    Capsule()
//                        .frame(width: 40, height: 5)
//                        .padding(.vertical, 15)
//                        .toolbarBackground(.hidden, for: .navigationBar)
//                        .opacity(animateContent ? 1 : 0)
//                    //Fixing Slide Animation
//                        .offset(y: animateContent ? 0 : size.height)
//                    
//                    HStack {
//                        //Artwork
//                        GeometryReader {
//                            let size = $0.size
//                            
//                            Image("Image")
//                                .resizable()
//                                .aspectRatio(contentMode: .fill)
//                                .frame(width: 80, height: 80)
//                                .clipShape(RoundedRectangle(cornerRadius: animateContent ? 5 : 5, style: .continuous))
//                        }
//                        .matchedGeometryEffect(id: "Album Cover", in: animation)
//                        //Square Artwork Image
//                        .frame(width: 80, height: 80)
//                        .padding(.top, -25)
//                        .padding(.vertical, size.height < 700 ? 10 : 15)
//                        
//                        VStack(alignment: .leading, spacing: 4) {
//                            Text("Song Name")
//                                .font(.title3)
//                                .fontWeight(.semibold)
//
//                            Text("Artist")
//                                .foregroundColor(.gray)
//                        }
//                        .padding(.top, -15)
//                        .frame(maxWidth: .infinity, alignment: .center)
//                        
//                        Button {
//                            liked.toggle()
//                        } label: {
//                            Image(liked ? "liked" : "unliked")
//                                .foregroundColor(.white)
//                                .font(.title)
//                        }
//                        .padding(.top, -30)
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
//                                .padding(.bottom, 40)
//                                .font(.title2)
//                                .foregroundColor(.white)
//                                .padding(12)
//                                .padding(.leading, 12)
//                        }
//                    }
//                        //Player Sliders
//                        PlayerButtons(size: size)
//                            .offset(y: animateContent ? 0 : size.height)
//                }
//                .offset(y: animateContent ? 0 : size.height)
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
//    struct upnextQueue: View {
//        var body: some View {
//            VStack {
//                Image("Image")
//                    .resizable()
//                    .aspectRatio(contentMode: .fill)
//            }
//            .frame(width: 343, height: 343)
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
//                upnextQueue()
//                VStack(spacing: spacing) {
//                    
//                    //Song Duration Slider
//                    Capsule()
//                        .fill(.gray)
//                        .frame(height: 8)
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
//                    .padding(.top, -10)
//                    .foregroundColor(.gray)
//                }
//                
//                //MARK: Playback Controls
//                HStack(spacing: size.width * 0.18) {
//                    BackwardButton()
//                    
//                    Button {
//                        //Play/Pause Function
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
//                .padding(.top, -18)
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
//                        
//                        AirPlayButton()
//                            .frame(width: 50, height: 50)
//                            .padding(.top, -13)
//                        .padding(.horizontal, 25)
//                        
//                        NavigationStack {
//                            NavigationLink(destination: Player(videoID: "", expandPlayer: $expandPlayer, animation: animation)) { Image(systemName: "list.bullet")
//                                    .font(.title2)
//                            }
//                        }
//                        .padding(.top, 3)
//                    }
//                    .foregroundColor(.white)
//                    .blendMode(.overlay)
//                }
//                .padding(.bottom, 10)
//            }
//        }
//    }
//}
