//
//  Player Controls.swift
//  cisum
//
//  Created by Aarav Gupta on 30/03/24.
//

import SwiftUI
import MediaPlayer
import AVKit

// MARK: - AirPlayButton
struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let routePickerView = AVRoutePickerView()
        routePickerView.tintColor = .white
        routePickerView.activeTintColor = .white
        routePickerView.prioritizesVideoDevices = false
        return routePickerView
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

// MARK: - PlayPauseButton
struct PlayPauseButton: View {
    @State private var isPlaying = false
    @State private var transparency: Double = 0.0
    
    var body: some View {
        Button {
            togglePlayPause()
        } label: {
            ZStack {
                Circle()
                    .frame(width: 35, height: 35)
                    .opacity(transparency)
                Image(systemName: "pause.fill")
                    .font(.system(size: 25))
                    .scaleEffect(isPlaying ? 1 : 0)
                    .opacity(isPlaying ? 1 : 0)
                    .animation(.interpolatingSpring(stiffness: 170, damping: 15), value: isPlaying)
                Image(systemName: "play.fill")
                    .font(.system(size: 25))
                    .scaleEffect(isPlaying ? 0 : 1)
                    .opacity(isPlaying ? 0 : 1)
                    .animation(.interpolatingSpring(stiffness: 170, damping: 15), value: isPlaying)
            }
        }
    }
    
    private func togglePlayPause() {
        isPlaying.toggle()
        transparency = 0.6
        withAnimation(.easeOut(duration: 0.2)) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                transparency = 0.0
            }
        }
    }
}

// MARK: - ForwardButton
struct ForwardButton: View {
    @State private var isForwarded = false
    @State private var transparency: Double = 0.0
    
    var body: some View {
        Button {
            isForwarded.toggle()
            transparency = 0.6
            withAnimation(.easeOut(duration: 0.2)) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    transparency = 0.0
                }
            }
        } label: {
            ZStack {
                Circle()
                    .frame(width: 65, height: 65)
                    .opacity(transparency)
                Image(systemName: "forward.fill")
                    .font(.system(size: 30))
                    .animation(.interpolatingSpring(stiffness: 170, damping: 15), value: isForwarded)
            }
        }
    }
}

// MARK: - BackwardButton
struct BackwardButton: View {
    @State private var isBackwarded = false
    @State private var transparency: Double = 0.0
    
    var body: some View {
        Button {
            isBackwarded.toggle()
            transparency = 0.6
            withAnimation(.easeOut(duration: 0.2)) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    transparency = 0.0
                }
            }
        } label: {
            ZStack {
                Circle()
                    .frame(width: 65, height: 65)
                    .opacity(transparency)
                Image(systemName: "backward.fill")
                    .font(.system(size: 30))
                    .animation(.interpolatingSpring(stiffness: 170, damping: 15), value: isBackwarded)
            }
        }
    }
}


struct SongOrVideo<Indicator: View>: View {
    var tabs: [songorvideo]
    @Binding var activeTab: songorvideo
    var height: CGFloat = 35
    var displayAsText = true
    var font: Font = .title3
    var activeTint: Color
    var inActiveTint: Color
    // Indicator View
    @ViewBuilder var indicatorView: (CGSize) -> Indicator
    
    @State private var minX: CGFloat = .zero
    @State private var excessTabWidth: CGFloat = .zero
    
    var body: some View {
        GeometryReader { geometry in
            let containerWidthForEachTab = geometry.size.width / CGFloat(tabs.count)
            
            HStack(spacing: 0) {
                ForEach(tabs, id: \.rawValue) { tab in
                    Text(tab.rawValue)
                        .font(font)
                        .fontWeight(.semibold)
                        .foregroundStyle(activeTab == tab ? activeTint : inActiveTint)
                        .animation(.snappy, value: activeTab)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let index = tabs.firstIndex(of: tab), let activeIndex = tabs.firstIndex(of: activeTab) {
                                activeTab = tab
                                
                                withAnimation(Animation.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0)) {
                                    excessTabWidth = containerWidthForEachTab * CGFloat(index - activeIndex)
                                }
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    withAnimation(Animation.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0)) {
                                        minX = containerWidthForEachTab * CGFloat(index)
                                        excessTabWidth = 0
                                    }
                                }
                            }
                        }
                        .background(alignment: .leading) {
                            if tabs.first == tab {
                                GeometryReader { indicatorGeometry in
                                    let size = indicatorGeometry.size
                                    
                                    indicatorView(size)
                                        .frame(width: size.width + (excessTabWidth < 0 ? -excessTabWidth : excessTabWidth), height: size.height)
                                        .frame(width: size.width, alignment: excessTabWidth < 0 ? .trailing : .leading)
                                        .offset(x: minX)
                                }
                            }
                        }
                }
            }
            .frame(height: height)
        }
    }
}


enum songorvideo: String, CaseIterable {
  case song = "Song"
  case video = "Video"
}

#Preview {
    Main(videoID: "")
}
