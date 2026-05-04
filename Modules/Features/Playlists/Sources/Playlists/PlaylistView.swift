//
//  PlaylistView.swift
//  Playlists
//
//  Created by Aarav Gupta on 29/04/26.
//

import SwiftUI

struct PlaylistView: View {
    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            
            ZStack {
                LinearGradient(colors: [.black, .accentColor, .accentColor, .accentColor], startPoint: .bottom, endPoint: .top)
                
                ScrollView {
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: size.width, height: size.width)
                        .overlay {
                            VStack(alignment: .leading) {
                                Text("Thriller")
                                    .font(.largeTitle)
                                    .fontWeight(.semibold)
                                
                                Button {
                                    
                                } label: {
                                    HStack(spacing: 4) {
                                        Text("Michael Jackson")
                                            .textCase(.uppercase)
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.callout)
                                    }
                                    .fontWeight(.semibold)
                                }
                                .buttonStyle(.plain)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                            .padding()
                        }
                    
                    HStack {
                        Button {
                            
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 50)
                                
                                Text("Play")
                            }
                        }
                        .frame(width: 160, height: 48)
                        .buttonStyle(.plain)
                    }
                    
                    ForEach(0..<10) {_ in
                        VStack {
                            HStack {
                                Text("1")
                                
                                Text("Michael Jackson")
                                
                                Spacer()
                                
                                Group {
                                    Image(systemName: "arrow.down.to.line.alt")
                                    
                                    Image(systemName: "star")
                                    
                                    Menu {
                                        Button {
                                            
                                        } label: {
                                            Text("Download")
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis")
                                    }
                                    .menuStyle(.button)
                                    .buttonStyle(.plain)
                                }
                                .font(.system(size: 20))
                            }
                            .fontWeight(.semibold)
                        }
                        .padding()
                        
                        Divider()
                            .padding(.horizontal)
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    PlaylistView()
}
