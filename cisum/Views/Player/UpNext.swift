////
////  UpNext.swift
////  cisum
////
////  Created by Aarav Gupta on 09/03/24.
////
//
//import SwiftUI
//
//struct UpNext: View {
//    let AccentColor = Color(red : 0.9764705882352941, green: 0.17647058823529413, blue: 0.2823529411764706)
//    @State private var activeTab: songorvideo = .song
//    @Binding var expandPlayer: Bool
//    var animation: Namespace.ID
//    @State private var animateContent: Bool = false
//    @State private var offsetY: CGFloat = 0
//    @State private var liked: Bool = false
//    @State private var isPlaying: Bool = false
//    
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
//                    Capsule()
//                        .frame(width: 40, height: 5)
//                        .padding(.vertical, 15)
//                        .toolbarBackground(.hidden, for: .navigationBar)
//                        .opacity(animateContent ? 1 : 0)
//                    //Fixing Slide Animation
//                        .offset(y: animateContent ? 0 : size.height)
//                    
//                    //Artwork
//                    GeometryReader {
//                        let size = $0.size
//                        
//                        Image("Image")
//                            .resizable()
//                            .aspectRatio(contentMode: .fill)
//                            .frame(width: size.width, height: size.height)
//                            .clipShape(RoundedRectangle(cornerRadius: animateContent ? 15 : 5, style: .continuous))
//                    }
//                    .matchedGeometryEffect(id: "Album Cover", in: animation)
//                    //Square Artwork Image
//                    .frame(height: size.width - 50)
//                    .padding(.top, -30)
//                    .padding(.vertical, size.height < 700 ? 10 : 15)
//                    
//                    //Player Controls
//                    PlayerControls(size: size)
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
//    func PlayerControls(size: CGSize) -> some View {
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
//                        Text("-:--")
//                            .font(.caption)
//                        
//                        Spacer(minLength: 0)
//                        
//                        Text("-:--")
//                            .font(.caption)
//                    }
//                    .foregroundColor(.gray)
//                }
//                .frame(height: size.height / 2.5, alignment: .top)
//                
//                //MARK: Playback Controls
//                HStack(spacing: size.width * 0.18) {
//                    Button {
//                        
//                    } label: {
//                        Image(systemName: "backward.fill")
//                            .font(.title)
//                    }
//                    
//                    PlayPauseButton()
//                    
//                    Button {
//                        
//                    } label: {
//                        Image(systemName: "forward.fill")
//                            .font(.title)
//                    }
//                }
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
//                        Button {
//                            
//                        } label: {
//                            Image(systemName: "quote.bubble")
//                                .font(.title2)
//                        }
//                        Button {
//                            
//                        } label: {
//                            Image(systemName: "airplayaudio")
//                                .font(.title2)
//                        }
//                        .padding(.horizontal, 25)
//                        Button {
//                            UpNext(expandPlayer: $expandPlayer, animation: animation)
//                        } label: {
//                            Image(systemName: "list.bullet")
//                                .font(.title2)
//                        }
//                    }
//                    .foregroundColor(.white)
//                    .blendMode(.overlay)
//                    .padding(.top, spacing)
//                }
//                .padding(.bottom, 25)
//                .frame(height: size.height / 2.5, alignment: .bottom)
//            }
//        }
//    }
//}
//
//#Preview {
//    Main()
//}
