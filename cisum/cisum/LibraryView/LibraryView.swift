//
//  LibraryView.swift
//  cisum
//
//  Created by Aarav Gupta on 18/02/24.
//

import SwiftUI

struct LibraryView: View {
    var body: some View {
        NavigationView {
            VStack {
                List {
                    // MARK: - Playlists
                    
                    Button(action: { print("Playlist button pressed")
                    }, label: {
                        HStack {
                            Label("Playlists", systemImage: "music.note.list")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                    })
                    .padding(.vertical, 8)
                    
                    // MARK: - Artist
                    
                    Button(action: { print("Artist button pressed") },
                           label: {
                        HStack {
                            Label("Artist", systemImage: "music.mic")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                    })
                    .padding(.vertical, 8)
                    
                    // MARK: - Albums
                    
                    Button(action: { print("Album button pressed") },
                           label: {
                        HStack {
                            Label("Album", systemImage: "square.stack")
                            Spacer()
                            Image(systemName: "chevron.right").font(.callout)
                                .foregroundColor(.secondary)
                        }
                    })
                    .padding(.vertical, 8)
                    
                    // MARK: - Genres
                    
                    Button(action: { print("guitars button pressed") }, label: {
                        HStack {
                            Label("Genres", systemImage: "guitars")
                            Spacer()
                            Image(systemName: "chevron.right").font(.callout)
                                .foregroundColor(.secondary)
                        }
                    })
                    .padding(.vertical, 8)
                    
                    // MARK: - Downloaded
                    
                    Button(action: { print("Download button pressed") }, label: {
                        HStack {
                            Label("Downloaded", systemImage: "arrow.down.circle")
                            Spacer()
                            Image(systemName: "chevron.right").font(.callout)
                                .foregroundColor(.secondary)
                        }
                    })
                    .padding(.vertical, 8)
                    
                    HStack(alignment: .center) {
                        Button(action: {},
                               label: { Text("Recently Added") })
                        Spacer()
                    }.font(.title2)
                        .bold()
                        .foregroundColor(.primary)
                    
                    RecentlyAdded()
                    
                }.listStyle(.plain)
                    .scrollIndicators(.hidden)
                    .navigationTitle("Library")
                    .navigationBarItems(trailing: EditButton())
                    .accentColor(.red)
            }
        }
    }
}

#Preview {
    LibraryView()
}
