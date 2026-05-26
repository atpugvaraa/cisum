//
//  ArtistDiscography.swift
//  Artists
//
//  Created by Aarav Gupta on 01/05/26.
//

import SwiftUI
import SwiftData
import Models

struct ArtistDiscography: View {
    let artist: Artist
    
    @Query private var albums: [Album]
    
    init(artist: Artist) {
        self.artist = artist
        let artistID = artist.artistID
        _albums = Query(filter: #Predicate<Album> { $0.primaryArtistID == artistID })
    }
    
    var body: some View {
        if !albums.isEmpty {
            VStack(alignment: .leading) {
                HStack(alignment: .center, spacing: 4) {
                    Text("Discography")
                        .font(.title)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 18))
                }
                .bold()
                .padding(.bottom)
                
                ForEach(albums, id: \.albumID) { album in
                    VStack {
                        HStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 50, height: 50)
                                .overlay {
                                    if let artwork = album.artworkURLString, let url = URL(string: artwork) {
                                        AsyncImage(url: url) { phase in
                                            if let image = phase.image {
                                                image.resizable().scaledToFill()
                                            }
                                        }
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(album.title)
                                    .lineLimit(1)
                                
                                if let year = album.releaseDateString {
                                    Text(year)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 16) {
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
                    
                    Divider()
                        .padding(.horizontal)
                }
            }
            .padding()
        }
    }
}
