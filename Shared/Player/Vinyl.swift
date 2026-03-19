//
//  Vinyl.swift
//  cisum
//
//  Created by Aarav Gupta on 19/03/26.
//

import SwiftUI

struct Vinyl<Content: View>: View {
    let content: () -> Content
    
    @Environment(PlayerViewModel.self) private var playerViewModel
    
    @State private var rotation: Double = 0
    @State private var speed: Double = 0
    @State private var lastUpdate: Date = .now
    
    let targetMaxSpeed: Double = 35
    let tauStart: Double = 0.6
    let tauStop: Double = 0.67
    
#if DEBUG
    @ObserveInjection var forceRedraw
#endif
    
    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date
            let delta = now.timeIntervalSince(lastUpdate)
            
            vinylOverlay
                .overlay {
                    LinearGradient(colors: [.black, .black, .black.opacity(0.8), .black.opacity(0.6), .clear, .clear, .clear, .clear], startPoint: .bottom, endPoint: .top)
                }
                .onChange(of: timeline.date) {
                    updatePhysics(delta: delta)
                    lastUpdate = now
                }
        }
        .background(Color(hex: "101010"))
        .enableInjection()
    }
    
    @ViewBuilder
    var vinylOverlay: some View {
        ZStack {
            Group {
                Circle()
                    .fill(.clear)
                    .overlay {
                        content()
                    }
                    .clipShape(.circle)
                    .padding(75)
                
                Image(.vinylGrooves)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .opacity(0.5)
                
                Image(.vinylOverlay)
                    .resizable()
                    .interpolation(.low)
                    .scaledToFit()
            }
            .rotationEffect(.degrees(rotation))
            
            Image(.vinylCenter)
                .resizable()
        }
        .frame(width: 1200, height: 1200)
        .offset(y: 220)
    }
    
    private func updatePhysics(delta: Double) {
        let targetSpeed = playerViewModel.isPlaying ? targetMaxSpeed : 0
        let tau = playerViewModel.isPlaying ? tauStart : tauStop
        
        let alpha = 1 - exp(-delta / tau)
        speed += (targetSpeed - speed) * alpha
        
        rotation += speed * delta
    }
}

#Preview {
    Vinyl {
        Image(.notPlaying)
            .resizable()
    }
    .preferredColorScheme(.dark)
}
