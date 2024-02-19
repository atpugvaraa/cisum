//
//  MiniPlayer.swift
//  cisum
//
//  Created by Aarav Gupta on 18/02/24.
//
import SwiftUI

struct Player: View {
    var animation: Namespace.ID
    @Binding var expand: Bool

    var height = UIScreen.main.bounds.height / 3
    var safearea = UIApplication.shared.windows.first?.safeAreaInsets
    @State private var player: CGFloat = 0
    @State private var volume: CGFloat = 0
    @State private var isShowingUpNextView = false
    @State private var isMusicPlaying = false
    @State private var isLiked = false

    var body: some View {
        VStack {
            Capsule()
                .fill(Color.gray)
                .frame(width: expand ? 60 : 0, height: expand ? 4 : 0)
                .opacity(expand ? 1 : 0)
                .padding(.top, expand ? safearea?.top : 0)
                .padding(.vertical, expand ? 30 : 0)

            HStack(alignment: .center, spacing: 15) {
                if expand { Spacer(minLength: 0) }
                Image("KR$NA")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: expand ? height : 48, height: expand ? height : 48)
                    .cornerRadius(15)
                    .matchedGeometryEffect(id: "Image", in: animation)

                if !expand {
                    Text("Joota Japani")
                        .font(.title3)
                        .fontWeight(.bold)
                }

                Spacer(minLength: 0)

                if !expand {
                    Button(action: {}) {
                        Image(systemName: "backward.fill")
                            .font(.title2)
                            .foregroundColor(.primary)
                    }

                    Button(action: {
                        withAnimation(.spring()) {
                            isMusicPlaying.toggle()
                        }
                    }) {
                        Image(systemName: isMusicPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .foregroundColor(.primary)
                    }

                    Button(action: {}) {
                        Image(systemName: "forward.fill")
                            .font(.title2)
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding(.horizontal)

            VStack {
                HStack {
                    if expand {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Joota Japani")
                                .font(.title2)
                                .foregroundColor(Color.primary)
                                .fontWeight(.bold)
                                .matchedGeometryEffect(id: "Text", in: animation)
                            Text("KR$NA")
                                .font(.title3)
                                .foregroundColor(Color.secondary)
                        }
                    }
                    Spacer(minLength: 0)

                    Button(action: {
                        withAnimation(.spring()) {
                            isLiked.toggle()
                        }
                    }) {
                        ZStack {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .font(.title2)
                                .foregroundColor(.primary)
                        }
                    }

                    Button(action: {}) {
                        ZStack {
                            Image(systemName: "ellipsis")
                                .font(.title2)
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.leading)
                }
                .padding()
                .padding(.top)

                HStack {
                    Slider(value: $player)
                }
                .padding()
                .accentColor(.primary)

                HStack {
                    Spacer()
                    Button(action: {}) {
                        Image(systemName: "backward.fill")
                    }

                    Spacer()

                    Button(action: {
                        withAnimation(.spring()) {
                            isMusicPlaying.toggle()
                        }
                    }) {
                        Image(systemName: isMusicPlaying ? "pause.fill" : "play.fill")
                    }

                    Spacer()
                    Button(action: {}) {
                        Image(systemName: "forward.fill")
                    }

                    Spacer()
                }
                .font(.largeTitle)
                .padding()
                .foregroundColor(.primary)

                HStack {
                    Image(systemName: "speaker")
                    Slider(value: $volume)
                    Image(systemName: "speaker.wave.3")
                }
                .padding()
                .accentColor(.primary)

                HStack(spacing: 15) {
                    Spacer()
                    Button(action: {}) {
                        Image(systemName: "quote.bubble")
                    }
                    Spacer()
                    Button(action: {}) {
                        Image(systemName: "airplayaudio")
                    }
                    Spacer()
                    Button(action: { isShowingUpNextView.toggle() }) {
                        Image(systemName: "list.bullet")
                    }
                    .sheet(isPresented: $isShowingUpNextView) {
                        UpNextView()
                    }
                    Spacer()
                }
                .font(.title2)
                .foregroundColor(.primary)

                Spacer(minLength: 0)
            }
            .frame(width: expand ? nil : 0, height: expand ? nil : 0)
            .opacity(expand ? 1 : 0)
        }
        .frame(maxHeight: expand ? .infinity : 68)
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(10)
        .offset(y: expand ? 0 : -48)
        .onTapGesture {
            withAnimation(.spring()) {
                expand.toggle()
            }
        }
        .ignoresSafeArea(.all)
    }
}
