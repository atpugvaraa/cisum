//
//  RecentlyAdded.swift
//  cisum
//
//  Created by Aarav Gupta on 18/02/24.
//
import SwiftUI

struct RecentlyAdded: View {
    var body: some View {
        ScrollView(.vertical,showsIndicators: false)
        {
            VStack{
                // MARK: - Firt column
                HStack{
                    
                    HorizontalScollBottonCard( imageName: "Play-2", artistName: "Water - Single", SubartistName: "Tyla")
                    
                    HorizontalScollBottonCard( imageName: "Play-4", artistName: "Shazam", SubartistName: "Playlist")
                    
                }
                HStack{
                    HorizontalScollBottonCard( imageName: "Play-5", artistName: "Calm", SubartistName: "Playlist")
                    
                    HorizontalScollBottonCard( imageName: "Play-6", artistName: "Groove", SubartistName: "Mix")
                }
                HStack{
                    HorizontalScollBottonCard( imageName: "Play-1", artistName: "Electric", SubartistName: "Mix")
                    
                    HorizontalScollBottonCard( imageName: "Play-3", artistName: "Made for you", SubartistName: "Curated Playlist")
                }
                HStack{
                    
                    HorizontalScollBottonCard( imageName: "Play-7", artistName: "Wave - Single", SubartistName: "CuBox")
                    
                    HorizontalScollBottonCard( imageName: "Play-8", artistName: "Drip Harder", SubartistName: "Mia")
                    
                }
                HStack{
                    
                    HorizontalScollBottonCard( imageName: "Play-9", artistName: "Groove", SubartistName: "Swift")
                    
                    HorizontalScollBottonCard( imageName: "Play-10", artistName: "The Underground", SubartistName: "Darshan Raval")
                    
                }
            }
        }
    }
}

#Preview {
    RecentlyAdded()
}
