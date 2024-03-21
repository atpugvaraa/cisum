//
//  Library.swift
//  cisum
//
//  Created by Aarav Gupta on 09/03/24.
//

import SwiftUI

struct Library: View {
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

struct RecentlyAdded: View {
    var body: some View {
        ScrollView(.vertical,showsIndicators: false)
        {
            VStack{
                // MARK: - Firt column
                HStack{

                    HorizontalScollBottomCard( imageName: "Play-2", artistName: "Water - Single", SubartistName: "Tyla")

                    HorizontalScollBottomCard( imageName: "Play-4", artistName: "Shazam", SubartistName: "Playlist")

                }
                HStack{
                    HorizontalScollBottomCard( imageName: "Play-5", artistName: "Calm", SubartistName: "Playlist")

                    HorizontalScollBottomCard( imageName: "Play-6", artistName: "Groove", SubartistName: "Mix")
                }
                HStack{
                    HorizontalScollBottomCard( imageName: "Play-1", artistName: "Electric", SubartistName: "Mix")

                    HorizontalScollBottomCard( imageName: "Play-3", artistName: "Made for you", SubartistName: "Curated Playlist")
                }
                HStack{

                    HorizontalScollBottomCard( imageName: "Play-7", artistName: "Wave - Single", SubartistName: "CuBox")

                    HorizontalScollBottomCard( imageName: "Play-8", artistName: "Drip Harder", SubartistName: "Mia")

                }
                HStack{

                    HorizontalScollBottomCard( imageName: "Play-9", artistName: "Groove", SubartistName: "Swift")

                    HorizontalScollBottomCard( imageName: "Play-10", artistName: "The Underground", SubartistName: "Darshan Raval")

                }
            }
        }
    }
}

#Preview {
    Library()
}
