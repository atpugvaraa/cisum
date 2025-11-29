//
//  DynamicPlayerIsland.swift
//  cisum
//
//  Created by Aarav Gupta on 13/03/26.
//

import SwiftUI

struct DynamicPlayerIsland: View {
    @State var isClicked: Bool = false
    @Namespace private var namespace
    
    var body: some View {
        if #available(macOS 26.0, iOS 26.0, *) {
            ZStack {
                if !isClicked {
                    RoundedRectangle(cornerRadius: 50)
                        .fill(.primary.opacity(0.6))
                        .glassEffect(.regular)
                        .matchedGeometryEffect(id: "GLASS", in: namespace)
                        .frame(height: 80)
                        .overlay {
                            HStack {
                                HStack {
                                    Circle()
                                        .matchedGeometryEffect(id: "Artwork", in: namespace)
                                    
                                    Text("Now Playing")
                                        .fontWeight(.semibold)
                                        .matchedGeometryEffect(id: "SongInfo", in: namespace)
                                }
                                .padding(13)
                                
                                Spacer()
                                
                                HStack {
                                    Image(systemName: "backward.fill")
                                    
                                    Image(systemName: "play.fill")
                                    
                                    Image(systemName: "forward.fill")
                                }
                                .padding()
                                .fontWeight(.bold)
                                .font(.title3)
                                .matchedGeometryEffect(id: "Controls", in: namespace)
                            }
                            
                            Capsule()
                                .fill(.clear)
                                .matchedGeometryEffect(id: "scrubber", in: namespace)
                                .frame(height: 8)
                                .padding(.horizontal)
                        }
                }
                
                if isClicked {
                    RoundedRectangle(cornerRadius: 30)
                        .fill(.primary.opacity(0.6))
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 30))
                        .matchedGeometryEffect(id: "GLASS", in: namespace)
                        .frame(height: 200)
                        .overlay {
                            VStack {
                                HStack(alignment: .center) {
                                    HStack {
                                        RoundedRectangle(cornerRadius: 16)
                                            .matchedGeometryEffect(id: "Artwork", in: namespace)
                                            .frame(width: 70, height: 70)
                                        
                                        VStack(alignment: .leading) {
                                            Text("Now Playing")
                                            
                                            Text("Artist")
                                                .font(.subheadline)
                                        }
                                        .fontWeight(.semibold)
                                        .matchedGeometryEffect(id: "SongInfo", in: namespace)
                                    }
                                    .padding(13)
                                    
                                    Spacer()
                                }
                                
                                Spacer()
                                
                                Capsule()
                                    .matchedGeometryEffect(id: "scrubber", in: namespace)
                                    .frame(height: 8)
                                    .padding(.horizontal)
                                
                                Spacer()
                                
                                HStack {
                                    Image(systemName: "backward.fill")
                                    
                                    Image(systemName: "play.fill")
                                    
                                    Image(systemName: "forward.fill")
                                }
                                .padding()
                                .fontWeight(.bold)
                                .font(.title)
                                .matchedGeometryEffect(id: "Controls", in: namespace)
                                
                                Spacer()
                            }
                        }
                }
            }
            .padding()
            .onTapGesture {
                isClicked.toggle()
            }
            .animation(.bouncy, value: isClicked)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

#Preview {
    DynamicPlayerIsland()
}
