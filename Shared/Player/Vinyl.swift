//
//  Vinyl.swift
//  cisum
//
//  Created by Aarav Gupta on 19/03/26.
//

import SwiftUI

struct Vinyl<Content: View>: View {
    let content: () -> Content
    let previous: (() -> AnyView)?
    let upnext: (() -> AnyView)?
    
    @Environment(PlayerViewModel.self) private var playerViewModel
    
    @State private var phaseStartAngle: Double = 0
    @State private var phaseStartDate: Date?
    @State private var phaseStartSpeed: Double = 0
    @State private var phaseTargetSpeed: Double = 0
    @State private var phaseTau: Double = 0.67
    
    private let targetMaxSpeed: Double = 35
    private let tauStart: Double = 0.6
    private let tauStop: Double = 0.67
    
#if DEBUG
    @ObserveInjection var forceRedraw
#endif
    
    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                ZStack {
                    VStack {
                        HStack {
                            ZStack {
                                previousVinyl
                                
                                VStack(alignment: .leading) {
                                    Text("Previous Song")
                                    
                                    Text("Bruno Mars")
                                        .font(.caption)
                                }
                                .foregroundStyle(.white)
                                .fontWeight(.semibold)
                                .offset(x: -35, y: -40)
                            }
                            
                            Spacer()
                            
                            ZStack {
                                nextVinyl
                                
                                VStack(alignment: .trailing) {
                                    Text("Next Song")
                                    
                                    Text("Drake")
                                        .font(.caption)
                                }
                                .foregroundStyle(.white)
                                .fontWeight(.semibold)
                                .offset(x: 45, y: -35)
                            }
                        }
                        
                        Spacer()
                    }
                    .offset(y: 35)
                    
                    heroVinyl
                        .rotationEffect(.degrees(rotation(at: timeline.date)))
                        .overlay {
                            LinearGradient(
                                colors: [
                                    .black,
                                    .black,
                                    .black.opacity(0.8),
                                    .black.opacity(0.6),
                                    .clear,
                                    .clear
                                ],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        }
                        .position(
                            x: geo.size.width / 2,
                            y: {
                                switch geo.size.height {
                                case 844, 852:
                                    return geo.size.height * 0.77
                                case 874, 932, 956, 912, 926:
                                    return geo.size.height * 0.75
                                default:
                                    return geo.size.height * 0.76
                                }
                            }()
                        )
                }
            }
        }
        .background(Color(hex: "101010"))
        .onAppear {
            syncPlaybackState(at: .now)
        }
        .onChange(of: playerViewModel.isPlaying) { _, _ in
            syncPlaybackState(at: .now)
        }
        .enableInjection()
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
    var heroVinyl: some View {
        VinylDisk(size: 1080) {
            content()
        }
    }
    
    private func rotation(at date: Date) -> Double {
        guard let phaseStartDate else {
            return phaseStartAngle
        }

        let elapsed = max(date.timeIntervalSince(phaseStartDate), 0)
        let deltaSpeed = phaseStartSpeed - phaseTargetSpeed
        return phaseStartAngle + (phaseTargetSpeed * elapsed) + (deltaSpeed * phaseTau * (1 - exp(-elapsed / phaseTau)))
    }

    private func speed(at date: Date) -> Double {
        guard let phaseStartDate else { return 0 }
        let elapsed = max(date.timeIntervalSince(phaseStartDate), 0)
        return phaseTargetSpeed + (phaseStartSpeed - phaseTargetSpeed) * exp(-elapsed / phaseTau)
    }

    private func syncPlaybackState(at date: Date) {
        let currentAngle = rotation(at: date)
        let currentSpeed = speed(at: date)
        let nextTargetSpeed = playerViewModel.isPlaying ? targetMaxSpeed : 0
        let nextTau = playerViewModel.isPlaying ? tauStart : tauStop

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

            Image(.vinylGrooves)
                .resizable()
                .scaledToFill()
                .opacity(0.5)
                .padding(5)

            Image(.vinylOverlay)
                .resizable()
                .scaledToFill()

            Image(.vinylCenter)
                .resizable()
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    Vinyl {
        Image(.notPlaying)
            .resizable()
    } previous: {
        Image(.notPlaying)
            .resizable()
    } upnext: {
        Image(.notPlaying)
            .resizable()
    }
    .preferredColorScheme(.dark)
}


extension Vinyl {
    init(
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.content = content
        self.previous = nil
        self.upnext = nil
    }

    init<Previous: View>(
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder previous: @escaping () -> Previous
    ) {
        self.content = content
        self.previous = { AnyView(previous()) }
        self.upnext = nil
    }
    
    init<Upnext: View>(
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder upnext: @escaping () -> Upnext
    ) {
        self.content = content
        self.previous = nil
        self.upnext = { AnyView(upnext()) }
    }

    init<Previous: View, Upnext: View>(
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder previous: @escaping () -> Previous,
        @ViewBuilder upnext: @escaping () -> Upnext
    ) {
        self.content = content
        self.previous = { AnyView(previous()) }
        self.upnext = { AnyView(upnext()) }
    }
}
