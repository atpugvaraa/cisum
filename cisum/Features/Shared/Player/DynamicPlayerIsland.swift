//
//  DynamicPlayerIsland.swift
//  cisum
//
//  Created by Aarav Gupta on 13/03/26.
//

import SwiftUI

struct DynamicPlayerIsland: View {
#if os(iOS)
    @Namespace private var namespace

    #if DEBUG
    @ObserveInjection var forceRedraw
    #endif

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                ZStack {
                    RoundedRectangle(cornerRadius: 50)
                        .fill(.clear)
                        .glassEffect(.identity)
                        .matchedGeometryEffect(id: "GLASS", in: namespace)
                        .frame(height: 56)
                        .overlay {
                            HStack(spacing: 12) {
                                Circle()
                                    .matchedGeometryEffect(id: "Artwork", in: namespace)
                                    .frame(width: 40, height: 40)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Now Playing")
                                        .fontWeight(.semibold)
                                    Text("Artist")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                HStack(spacing: 14) {
                                    Image(systemName: "backward.fill")
                                    Image(systemName: "play.fill")
                                    Image(systemName: "forward.fill")
                                }
                                .font(.title3)
                                .fontWeight(.bold)
                            }
                            .padding(.leading, 5)
                            .padding(.trailing, 10)
                        }
                }
                .onTapGesture {
                    
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 50)
                        .fill(.bar)
                        .matchedGeometryEffect(id: "GLASS", in: namespace)
                        .frame(height: 45)
                        .overlay {
                            HStack(spacing: 12) {
                                Circle()
                                    .matchedGeometryEffect(id: "Artwork", in: namespace)
                                    .frame(width: 36, height: 36)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Now Playing")
                                        .fontWeight(.semibold)
                                    Text("Artist")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                HStack(spacing: 14) {
                                    Image(systemName: "backward.fill")
                                    Image(systemName: "play.fill")
                                    Image(systemName: "forward.fill")
                                }
                                .font(.title3)
                                .fontWeight(.bold)
                            }
                            .padding(.leading, 4)
                            .padding(.trailing, 10)
                        }
                }
                .padding(.horizontal, 20)
                .onTapGesture {
                    
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
        .enableInjection()
    }
#elseif os(macOS)
    @State private var isHovered: Bool = false
    @Namespace private var namespace

    #if DEBUG
    @ObserveInjection var forceRedraw
    #endif

    var body: some View {
        ZStack {
            if isHovered {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.clear)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
                    .matchedGeometryEffect(id: "GLASS", in: namespace)
                    .frame(height: 180)
                    .overlay {
                        VStack {
                            HStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .matchedGeometryEffect(id: "Artwork", in: namespace)
                                    .frame(width: 74, height: 74)
                                VStack(alignment: .leading) {
                                    Text("Now Playing")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                    Text("Artist")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding()
                            
                            Spacer()
                            
                            HStack {
                                Image(systemName: "backward.fill")
                                Image(systemName: "play.fill")
                                Image(systemName: "forward.fill")
                            }
                            .font(.title)
                            .padding()
                        }
                    }
            } else {
                RoundedRectangle(cornerRadius: 40)
                    .fill(.secondary.opacity(0.06))
                    .glassEffect(.regular)
                    .matchedGeometryEffect(id: "GLASS", in: namespace)
                    .frame(height: 70)
                    .overlay {
                        HStack {
                            Circle()
                                .matchedGeometryEffect(id: "Artwork", in: namespace)
                                .frame(width: 44, height: 44)
                            Text("Now Playing")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding(12)
                    }
            }
        }
        .padding()
        .onHover { hovering in
            withAnimation(.bouncy) {
                isHovered = hovering
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .enableInjection()
    }
#endif
}

#Preview {
    DynamicPlayerIsland()
}
