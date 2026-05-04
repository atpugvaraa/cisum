//
//  Vinyl.swift
//  cisum
//
//  Created by Aarav Gupta on 19/03/26.
//

import SwiftUI

struct VinylSideLabel {
    let title: String
    let subtitle: String?
}

public struct Vinyl<Content: View>: View {
    let content: () -> Content
    let previous: (() -> AnyView)?
    let upnext: (() -> AnyView)?
    let previousLabel: VinylSideLabel?
    let upnextLabel: VinylSideLabel?

    let isPlaying: Bool
    let accentColor: Color

    @State private var phaseStartAngle: Double = 0
    @State private var phaseStartDate: Date?
    @State private var phaseStartSpeed: Double = 0
    @State private var phaseTargetSpeed: Double = 0
    @State private var phaseTau: Double = 0.67

    private let targetMaxSpeed: Double = 35
    private let tauStart: Double = 0.6
    private let tauStop: Double = 0.67

    

    public var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                ZStack {
                    VStack {
                        HStack {
                            ZStack {
                                previousVinyl

                                if let previousLabel {
                                    sideLabel(previousLabel, alignment: .leading)
                                        .offset(x: -35, y: -40)
                                }
                            }

                            Spacer()

                            ZStack {
                                nextVinyl

                                if let upnextLabel {
                                    sideLabel(upnextLabel, alignment: .trailing)
                                        .offset(x: 45, y: -35)
                                }
                            }
                        }

                        Spacer()
                    }
                    .offset(y: 35)
                    
                    heroVinyl(timeline: timeline)
                        .overlay {
                            vinylShade
                        }
                        .position(
                            x: geo.size.width / 2,
                            y: heroCenterY(for: geo.size.height)
                        )
                }
            }
        }
        .background(Color(hex: "101010"))
        .onAppear {
            syncPlaybackState(at: .now)
        }
        .onChange(of: isPlaying) { _, _ in
            syncPlaybackState(at: .now)
        }

    }

    @ViewBuilder
    var previousVinyl: some View {
        if let previous {
            VinylDisk(size: 200) {
                previous()
            }
            .offset(x: -60)
        }
    }

    @ViewBuilder
    var nextVinyl: some View {
        if let upnext {
            VinylDisk(size: 200) {
                upnext()
            }
            .offset(x: 55)
        }
    }

    @ViewBuilder
    func heroVinyl(timeline: TimelineViewDefaultContext) -> some View {
        VinylDisk(size: 1080) {
            content()
        }
        .rotationEffect(.degrees(rotation(at: timeline.date)))
    }

    private var vinylShade: LinearGradient {
        let accent = accentColor
        return LinearGradient(
            colors: [
                .black,
                accent.opacity(0.92),
                accent.opacity(0.68),
                accent.opacity(0.42),
                .clear,
                .clear,
            ],
            startPoint: .bottom,
            endPoint: .top
        )
    }

    @ViewBuilder
    private func sideLabel(_ label: VinylSideLabel, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment) {
            Text(label.title)

            if let subtitle = label.subtitle,
                !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                Text(subtitle)
                    .font(.caption)
            }
        }
        .foregroundStyle(.white)
        .fontWeight(.semibold)
    }

    private func heroCenterY(for height: CGFloat) -> CGFloat {
        let compactAnchor: CGFloat = 850
        let tallAnchor: CGFloat = 930

        let ratio: CGFloat
        if height <= compactAnchor {
            ratio = 0.77
        } else if height >= tallAnchor {
            ratio = 0.75
        } else {
            let progress = (height - compactAnchor) / (tallAnchor - compactAnchor)
            ratio = 0.77 - (0.02 * progress)
        }

        return height * ratio
    }
    
    public func rotation(at date: Date) -> Double {
        guard let phaseStartDate else {
            return phaseStartAngle
        }

        let elapsed = max(date.timeIntervalSince(phaseStartDate), 0)
        let deltaSpeed = phaseStartSpeed - phaseTargetSpeed

        // Fast path once acceleration settles to steady-state motion.
        if abs(deltaSpeed) < 0.0001 {
            return phaseStartAngle + (phaseTargetSpeed * elapsed)
        }

        return phaseStartAngle + (phaseTargetSpeed * elapsed)
            + (deltaSpeed * phaseTau * (1 - exp(-elapsed / phaseTau)))
    }

    private func speed(at date: Date) -> Double {
        guard let phaseStartDate else { return 0 }
        let elapsed = max(date.timeIntervalSince(phaseStartDate), 0)
        let delta = phaseStartSpeed - phaseTargetSpeed
        if abs(delta) < 0.0001 {
            return phaseTargetSpeed
        }
        return phaseTargetSpeed + delta * exp(-elapsed / phaseTau)
    }

    private func syncPlaybackState(at date: Date) {
        let currentAngle = rotation(at: date)
        let currentSpeed = speed(at: date)
        let nextTargetSpeed = isPlaying ? targetMaxSpeed : 0
        let nextTau = isPlaying ? tauStart : tauStop

        phaseStartAngle = currentAngle
        phaseStartDate = date
        phaseStartSpeed = currentSpeed
        phaseTargetSpeed = nextTargetSpeed
        phaseTau = nextTau
    }
}

struct VinylDisk<Content: View>: View {
    let size: CGFloat
    let content: () -> Content
    
    var body: some View {
        ZStack {
            Circle()
                .fill(.clear)
                .overlay {
                    content()
                }
                .clipShape(.circle)
                .padding(1)

            Image.vinylGrooves
                .resizable()
                .scaledToFill()
                .opacity(0.5)
                .padding(5)

            Image.vinylOverlay
                .resizable()
                .scaledToFill()

            Image.vinylCenter
                .resizable()
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    Vinyl(isPlaying: false, accentColor: .blue) {
        Image.vinylNotPlaying
            .resizable()
    } previous: {
        Image.vinylNotPlaying
            .resizable()
    } upnext: {
        Image.vinylNotPlaying
            .resizable()
    }
    .preferredColorScheme(.dark)
}

public extension Vinyl {
    public init(
        isPlaying: Bool,
        accentColor: Color,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isPlaying = isPlaying
        self.accentColor = accentColor
        self.content = content
        self.previous = nil
        self.upnext = nil
        self.previousLabel = nil
        self.upnextLabel = nil
    }

    public init<Previous: View>(
        isPlaying: Bool,
        accentColor: Color,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder previous: @escaping () -> Previous,
        previousTitle: String? = nil,
        previousSubtitle: String? = nil
    ) {
        self.isPlaying = isPlaying
        self.accentColor = accentColor
        self.content = content
        self.previous = { AnyView(previous()) }
        self.upnext = nil
        self.previousLabel = Self.makeSideLabel(title: previousTitle, subtitle: previousSubtitle)
        self.upnextLabel = nil
    }

    public init<Upnext: View>(
        isPlaying: Bool,
        accentColor: Color,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder upnext: @escaping () -> Upnext,
        upnextTitle: String? = nil,
        upnextSubtitle: String? = nil
    ) {
        self.isPlaying = isPlaying
        self.accentColor = accentColor
        self.content = content
        self.previous = nil
        self.upnext = { AnyView(upnext()) }
        self.previousLabel = nil
        self.upnextLabel = Self.makeSideLabel(title: upnextTitle, subtitle: upnextSubtitle)
    }

    public init<Previous: View, Upnext: View>(
        isPlaying: Bool,
        accentColor: Color,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder previous: @escaping () -> Previous,
        @ViewBuilder upnext: @escaping () -> Upnext,
        previousTitle: String? = nil,
        previousSubtitle: String? = nil,
        upnextTitle: String? = nil,
        upnextSubtitle: String? = nil
    ) {
        self.isPlaying = isPlaying
        self.accentColor = accentColor
        self.content = content
        self.previous = { AnyView(previous()) }
        self.upnext = { AnyView(upnext()) }
        self.previousLabel = Self.makeSideLabel(title: previousTitle, subtitle: previousSubtitle)
        self.upnextLabel = Self.makeSideLabel(title: upnextTitle, subtitle: upnextSubtitle)
    }
    private static func makeSideLabel(title: String?, subtitle: String?) -> VinylSideLabel? {
        guard let title else { return nil }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return nil }

        let trimmedSubtitle = subtitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSubtitle = (trimmedSubtitle?.isEmpty == false) ? trimmedSubtitle : nil
        return VinylSideLabel(title: trimmedTitle, subtitle: normalizedSubtitle)
    }
}
