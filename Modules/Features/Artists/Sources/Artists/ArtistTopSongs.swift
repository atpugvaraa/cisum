//
//  ArtistTopSongs.swift
//  Artists
//
//  Created by Aarav Gupta on 01/05/26.
//

import SwiftUI

struct ArtistTopSongs: View {
    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .center, spacing: 4) {
                Text("Top Songs")
                    .font(.title)

                Image(systemName: "chevron.right")
                    .font(.system(size: 18))
            }
            .bold()
            .padding(.bottom)
            
            ForEach(0..<5) {_ in
                VStack {
                    HStack {
                        RoundedRectangle(cornerRadius: 6)
                            .frame(width: 50, height: 50)
                        
                        Text("Congratulations")
                        
                        Spacer()
                        
                        HStack(spacing: 16) {
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
                
                Divider()
                    .padding(.horizontal)
            }
        }
        .padding()
    }
}
