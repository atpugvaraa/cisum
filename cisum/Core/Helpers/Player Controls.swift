//
//  Player Controls.swift
//  cisum
//
//  Created by Aarav Gupta on 30/03/24.
//

import SwiftUI
import MediaPlayer
import AVKit

//MARK: Music Control Slider
struct MusicProgressSlider<T: BinaryFloatingPoint>: View {
  @Binding var value: T
  let inRange: ClosedRange<T>
  let activeFillColor: Color
  let fillColor: Color
  let emptyColor: Color
  let height: CGFloat
  let onEditingChanged: (Bool) -> Void

  // private variables
  @State private var localRealProgress: T = 0
  @State private var localTempProgress: T = 0
  @GestureState private var isActive: Bool = false
  @State private var progressDuration: T = 0

  init(
    value: Binding<T>,
    inRange: ClosedRange<T>,
    activeFillColor: Color,
    fillColor: Color,
    emptyColor: Color,
    height: CGFloat,
    onEditingChanged: @escaping (Bool) -> Void
  ) {
    self._value = value
    self.inRange = inRange
    self.activeFillColor = activeFillColor
    self.fillColor = fillColor
    self.emptyColor = emptyColor
    self.height = height
    self.onEditingChanged = onEditingChanged
  }

  var body: some View {
    GeometryReader { bounds in
      ZStack {
        VStack {
          ZStack(alignment: .center) {
            Capsule()
              .fill(emptyColor)
            Capsule()
              .fill(isActive ? activeFillColor : fillColor)
              .mask({
                HStack {
                  Rectangle()
                    .frame(width: max(bounds.size.width * CGFloat((localRealProgress + localTempProgress)), 0), alignment: .leading)
                  Spacer(minLength: 0)
                }
              })
          }
          .frame(height: bounds.size.height * 0.26)

          HStack {
            Text(progressDuration.asTimeString(style: .positional))
            Spacer(minLength: 0)
            Text("-" + (inRange.upperBound - progressDuration).asTimeString(style: .positional))
          }
          .font(.system(.caption, design: .rounded))
          .monospacedDigit()
          .foregroundColor(isActive ? fillColor : emptyColor)
        }
        .frame(width: isActive ? bounds.size.width * 1.04 : bounds.size.width, alignment: .center)
        //                .shadow(color: .black.opacity(0.1), radius: isActive ? 20 : 0, x: 0, y: 0)
        .animation(animation, value: isActive)
      }
      .frame(width: bounds.size.width, height: bounds.size.height, alignment: .center)
      .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
        .updating($isActive) { value, state, transaction in
          state = true
        }
        .onChanged { gesture in
          localTempProgress = T(gesture.translation.width / bounds.size.width)
          let prg = max(min((localRealProgress + localTempProgress), 1), 0)
          progressDuration = inRange.upperBound * prg
          value = max(min(getPrgValue(), inRange.upperBound), inRange.lowerBound)
        }.onEnded { value in
          localRealProgress = max(min(localRealProgress + localTempProgress, 1), 0)
          localTempProgress = 0
          progressDuration = inRange.upperBound * localRealProgress
        })
      .onChange(of: isActive) { newValue in
        value = max(min(getPrgValue(), inRange.upperBound), inRange.lowerBound)
        onEditingChanged(newValue)
      }
      .onAppear {
        localRealProgress = getPrgPercentage(value)
        progressDuration = inRange.upperBound * localRealProgress
      }
      .onChange(of: value) { newValue in
        if !isActive {
          localRealProgress = getPrgPercentage(newValue)
        }
      }
    }
    .frame(height: isActive ? height * 1.25 : height, alignment: .center)
  }

  private var animation: Animation {
    if isActive {
      return .spring()
    } else {
      return .spring(response: 0.5, dampingFraction: 0.5, blendDuration: 0.6)
    }
  }

  private func getPrgPercentage(_ value: T) -> T {
    let range = inRange.upperBound - inRange.lowerBound
    let correctedStartValue = value - inRange.lowerBound
    let percentage = correctedStartValue / range
    return percentage
  }

  private func getPrgValue() -> T {
    return ((localRealProgress + localTempProgress) * (inRange.upperBound - inRange.lowerBound)) + inRange.lowerBound
  }
}

//MARK: Volume Slider
struct VolumeSlider<T: BinaryFloatingPoint>: View {
  @Binding var value: T
  let inRange: ClosedRange<T>
  let activeFillColor: Color
  let fillColor: Color
  let emptyColor: Color
  let height: CGFloat
  let onEditingChanged: (Bool) -> Void

  // private variables
  @State private var localRealProgress: T = 0
  @State private var localTempProgress: T = 0
  @GestureState private var isActive: Bool = false

  var body: some View {
    GeometryReader { bounds in
      ZStack {
        HStack {
          Image(systemName: "speaker.fill")
            .font(.system(.title2))
            .blendMode(.overlay)
            .foregroundColor(isActive ? activeFillColor : fillColor)

          GeometryReader { geo in
            ZStack(alignment: .center) {
              Capsule()
                .fill(emptyColor)
              Capsule()
                .fill(isActive ? activeFillColor : fillColor)
                .mask({
                  HStack {
                    Rectangle()
                      .frame(width: max(geo.size.width * CGFloat((localRealProgress + localTempProgress)), 0), alignment: .leading)
                    Spacer(minLength: 0)
                  }
                })
            }
          }

          Image(systemName: "speaker.wave.3.fill")
            .blendMode(.overlay)
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundColor(isActive ? activeFillColor : fillColor)
        }
        .frame(width: isActive ? bounds.size.width * 1.04 : bounds.size.width, alignment: .center)
        //                .shadow(color: .black.opacity(0.1), radius: isActive ? 20 : 0, x: 0, y: 0)
        .animation(animation, value: isActive)
      }
      .frame(width: bounds.size.width, height: bounds.size.height, alignment: .center)
      .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
        .updating($isActive) { value, state, transaction in
          state = true
        }
        .onChanged { gesture in
          localTempProgress = T(gesture.translation.width / bounds.size.width)
          value = max(min(getPrgValue(), inRange.upperBound), inRange.lowerBound)
        }.onEnded { value in
          localRealProgress = max(min(localRealProgress + localTempProgress, 1), 0)
          localTempProgress = 0
        })
      .onChange(of: isActive) { newValue in
        value = max(min(getPrgValue(), inRange.upperBound), inRange.lowerBound)
        onEditingChanged(newValue)
      }
      .onAppear {
        localRealProgress = getPrgPercentage(value)
      }
      .onChange(of: value) { newValue in
        if !isActive {
          localRealProgress = getPrgPercentage(newValue)
        }
      }
    }
    .frame(height: isActive ? height * 2 : height, alignment: .center)
  }

  private var animation: Animation {
    if isActive {
      return .spring()
    } else {
      return .spring(response: 0.5, dampingFraction: 0.5, blendDuration: 0.6)
    }
  }

  private func getPrgPercentage(_ value: T) -> T {
    let range = inRange.upperBound - inRange.lowerBound
    let correctedStartValue = value - inRange.lowerBound
    let percentage = correctedStartValue / range
    return percentage
  }

  private func getPrgValue() -> T {
    return ((localRealProgress + localTempProgress) * (inRange.upperBound - inRange.lowerBound)) + inRange.lowerBound
  }
}

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

//MARK: PLAYERPLAYPAUSEBUTTON
struct PlayerPlayPause: View {
  @State private var isPlaying = false
  @State private var transparency: Double = 0.0

  var body: some View {
    Button {
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
  }
}

// MARK: - PlayPauseButton
struct PlayPauseButton: View {
  @State private var isPlaying = false
  @State private var transparency: Double = 0.0

  var body: some View {
    Button {
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

//MARK: Segmented Control
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
