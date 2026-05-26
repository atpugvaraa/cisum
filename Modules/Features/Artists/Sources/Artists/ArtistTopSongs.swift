//
//  ArtistTopSongs.swift
//  Artists
//
//  Created by Aarav Gupta on 01/05/26.
//

import SwiftUI
import SwiftData
import Models

struct ArtistTopSongs: View {
    let artist: Artist
    let onPlayTrack: (Int) -> Void
    
    @Query private var topTracks: [Song]
    
    init(artist: Artist, onPlayTrack: @escaping (Int) -> Void) {
        self.artist = artist
        self.onPlayTrack = onPlayTrack
        let artistID = artist.artistID
        _topTracks = Query(filter: #Predicate<Song> { $0.primaryArtistID == artistID })
    }
    
    var body: some View {
        if !topTracks.isEmpty {
            VStack(alignment: .leading) {
                HStack(alignment: .center, spacing: 4) {
                    Text("Top Songs")
                        .font(.title)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 18))
                }
                .bold()
                .padding(.bottom)
                
                ForEach(Array(topTracks.enumerated()), id: \.element.songID) { index, track in
                    Button {
                        onPlayTrack(index)
                    } label: {
                        VStack {
                            HStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 50, height: 50)
                                    .overlay {
                                        if let artwork = track.artworkURLString ?? artist.artworkURLString, let url = URL(string: artwork) {
                                            AsyncImage(url: url) { phase in
                                                if let image = phase.image {
                                                    image.resizable().scaledToFill()
                                                }
                                            }
                                        }
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                
                                Text(track.title)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                HStack(spacing: 16) {
                                    if track.isExplicit {
                                        Image(systemName: "e.square.fill")
                                            .foregroundStyle(.secondary)
                                            .font(.system(size: 14))
                                    }
                                    
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
                    }
                    .buttonStyle(.plain)
                    
                    Divider()
                        .padding(.horizontal)
                }
            }
            .padding()
        }
    }
}
