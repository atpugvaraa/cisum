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
    RecentlyAdded()
}
