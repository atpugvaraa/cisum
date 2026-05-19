//
//  RechordsView.swift
//  Rechords
//
//  Created by Aarav Gupta on 13/05/26.
//

import SwiftUI

struct RechordsView: View {
    @State private var weights: [CGFloat]
    let rechords = Array("Rechords")
    let letterWidths: [CGFloat] = [27.5, 20, 20.5, 22, 22, 20.5, 24.4, 18.5]

    let duration: Double = 1
    @State private var shimmerPhase: CGFloat = -1
    
    private static let backgroundColor = Color(red: 32/255, green: 34/255, blue: 46/255)
    private static let patches = Color(red: 40/255, green: 43/255, blue: 58/255)
    private static let highlights = Color(red: 162/255, green: 133/255, blue: 80/255)
    private static let textHighlights = Color(red: 185/255, green: 152/255, blue: 90/255)

    private static let fontsReady: Bool = {
        FontRegistration.registerFonts()
        FontRegistration.testVariableAxes()
        return true
    }()

    init() {
        _weights = State(initialValue: Array(repeating: 300, count: 8))
        _ = Self.fontsReady
    }

    var body: some View {
        ZStack {
            RechordsView.backgroundColor
            
            RechordsView.gradient
            
            grainOverlay
            
            VStack(alignment: .center, spacing: -6) {
                Text("cisum")
                    .font(.largeTitle)
                    .fontWidth(.expanded)
                    .fontWeight(.semibold)
                
                HStack(spacing: 0) {
                    Image(systemName: "star.fill")
                    
                    // "Re" — no shimmer
                    ForEach(Array(rechords.prefix(2).enumerated()), id: \.offset) { index, letter in
                        Text(String(letter))
                            .font(notoSerifItalic(size: 40, weight: weights[index]))
                            .frame(width: letterWidths[index])
                    }
                    
                    // "chords" — with shimmer
                    HStack(spacing: 0) {
                        ForEach(Array(rechords.dropFirst(2).enumerated()), id: \.offset) { index, letter in
                            let actualIndex = index + 2
                            Text(String(letter))
                                .font(notoSerifItalic(size: 40, weight: weights[actualIndex]))
                                .frame(width: letterWidths[actualIndex])
                                .offset(x: letter == "d" ? -1.5 : 0)
                        }
                    }
                    .overlay {
                        GeometryReader { geo in
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0.3),
                                    .init(color: .white.opacity(0.8), location: 0.5),
                                    .init(color: .clear, location: 0.7)
                                ],
                                startPoint: .bottomLeading,
                                endPoint: .topTrailing
                            )
                            .frame(width: geo.size.width * 3)
                            .offset(x: shimmerPhase * geo.size.width * 3 - geo.size.width)
                        }
                        .clipped()
                        .blendMode(.screen)
                        .allowsHitTesting(false)
                    }
                    .mask {
                        HStack(spacing: 0) {
                            chordsLetters()
                        }
                    }
                    
                    Image(systemName: "star.fill")
                        .padding(.leading, 2)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .safeAreaPadding(.top, 80)
            .task {
                withAnimation(.linear(duration: 3)) {
                    shimmerPhase = 1
                }
                await startWave()
            }
            .foregroundStyle(RechordsView.textHighlights)
        }
        .ignoresSafeArea()
    }
    
    private static let gradient = LinearGradient(
        colors: [
            .clear,
            RechordsView.highlights.opacity(0.01),
            RechordsView.highlights.opacity(0.02),
            RechordsView.highlights.opacity(0.03),
            RechordsView.highlights.opacity(0.05),
            RechordsView.highlights.opacity(0.06),
            RechordsView.highlights.opacity(0.08),
            RechordsView.highlights.opacity(0.10),
            RechordsView.highlights.opacity(0.12),
            RechordsView.highlights.opacity(0.16),
            RechordsView.highlights.opacity(0.20),
            RechordsView.highlights.opacity(0.24),
            RechordsView.highlights.opacity(0.32),
            RechordsView.highlights.opacity(0.40)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    @ViewBuilder
    private func chordsLetters() -> some View {
        ForEach(Array(rechords.dropFirst(2).enumerated()), id: \.offset) { index, letter in
            let actualIndex = index + 2
            Text(String(letter))
                .font(notoSerifItalic(size: 40, weight: weights[actualIndex]))
                .frame(width: letterWidths[actualIndex])
                .offset(x: letter == "d" ? -1.5 : 0)
        }
    }
    
    private var grainOverlay: some View {
        Canvas { context, size in
            var rng = SeededGenerator(seed: 42)
            for _ in 0..<3000 {
                let x = CGFloat.random(in: 0...size.width, using: &rng)
                let y = CGFloat.random(in: 0...size.height, using: &rng)
                let opacity = Double.random(in: 0.03...0.08, using: &rng)
                let dotSize = CGFloat.random(in: 0.5...1.5, using: &rng)
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: dotSize, height: dotSize)),
                    with: .color(.white.opacity(opacity))
                )
            }
        }
        .allowsHitTesting(false)
        .blendMode(.screen)
        .drawingGroup()
    }

    func startWave() async {
        let staggerDelay: Double = 0.2
        let expandDuration: Double = 1.2
        let contractDuration: Double = 0.8

        for i in rechords.indices {
            withAnimation(.easeInOut(duration: expandDuration).delay(Double(i) * staggerDelay)) {
                weights[i] = 550
            }
        }

        let expandPhase = Double(rechords.count - 1) * staggerDelay + expandDuration
        try? await Task.sleep(for: .seconds(expandPhase + 0.2))

        // Check if task was cancelled (view disappeared)
        guard !Task.isCancelled else { return }

        for i in rechords.indices {
            withAnimation(.easeOut(duration: contractDuration).delay(Double(i) * staggerDelay)) {
                weights[i] = 300
            }
        }

        let contractPhase = Double(rechords.count - 1) * staggerDelay + contractDuration
        try? await Task.sleep(for: .seconds(contractPhase + 0.3))

        guard !Task.isCancelled else { return }
        await startWave()
    }
}

#Preview {
    RechordsView()
}

struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    
    init(seed: UInt64) { state = seed }
    
    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
}
