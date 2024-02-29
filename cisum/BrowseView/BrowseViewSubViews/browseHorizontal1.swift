
//  browseHorizontal1.swift
//  cisum

//  Created by Aarav Gupta on 18/02/24.


import SwiftUI

struct browseHorizontal1: View {
    var body: some View {
        ScrollView(.horizontal , showsIndicators: false){
            HStack{
                ZStack {
                    
                    VStack{
                        HStack(alignment: .center,spacing: 0 ,content: {
                            Text("Add to your library".uppercased())
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                            Spacer()
                        })
                        
                        
                        HStack(alignment: .center,spacing: 0 ,content: {
                            Text("Hindi Pop Chill").fontWeight(.bold).font(.title3)
                            Spacer()
                        })
                        
                        
                        HStack(alignment: .center,spacing: 0 ,content: {
                            Text("Apple Music Indian Independent").font(.title3).foregroundStyle(.secondary)
                            Spacer()
                        })
                        
                        Image("Playlist-2")
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(20)
                            .frame(width: 350 , height: 232)
                    }
                    .frame(width: 350 , height: 350)
                }
                
                ZStack {
                
                    
                    VStack{
                        HStack(alignment: .center,spacing: 0 ,content: {
                            Text("LISTEN NOW".uppercased())
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                            Spacer()
                        })
                        
                        
                        HStack(alignment: .center,spacing: 0 ,content: {
                            Text("The New India").fontWeight(.bold).font(.title3)
                            Spacer()
                        })
                        
                        
                        HStack(alignment: .center,spacing: 0 ,content: {
                            Text("Apple Music").font(.title3).foregroundStyle(.secondary)
                            Spacer()
                        })
                        
                        Image("Playlist-3")
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(20)
                            .frame(width: 350 , height: 232)
                    }
                    .frame(width: 350 , height: 350)
                }
                
                ZStack {
                    VStack{
                        HStack(alignment: .center,spacing: 0 ,content: {
                            Text("UPDATED PLAYLIST".uppercased())
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                            Spacer()
                        })
                        
                        
                        HStack(alignment: .center,spacing: 0 ,content: {
                            Text("A-List Pop").fontWeight(.bold).font(.title3)
                            Spacer()
                        })
                        
                        
                        HStack(alignment: .center,spacing: 0 ,content: {
                            Text("Apple Music").font(.title3).foregroundStyle(.secondary)
                            Spacer()
                        })
                        
                        Image("Playlist-1")
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(20)
                            .frame(width: 350 , height: 232)
                    }
                    .frame(width: 350 , height: 350)
                }
            }
        }
        .padding(.horizontal)
//        .scrollClipDisabled()
//        .scrollTargetBehavior(.paging)
    }
}

#Preview {
    browseHorizontal1()
}
