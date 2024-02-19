//
//  HorizontalScrollBottom2.swift
//  cisum
//
//  Created by Aarav Gupta on 18/02/24.
//

import SwiftUI

struct HorizontalScrollBottom2: View {
    var body: some View {
        ScrollView(.horizontal ,showsIndicators: false){
            HStack {
                HorizontalScollBottonCard( imageName: "PlaylistPic-1", artistName: "Today's Hits", SubartistName: "Music Hits")
                
                HorizontalScollBottonCard( imageName: "PlaylistPic-4", artistName: "Verified Hits", SubartistName: "Music Pop")
                
                HorizontalScollBottonCard( imageName: "PlaylistPic-2", artistName: "Pure Focus", SubartistName: "Music Alternative")
                
                HorizontalScollBottonCard( imageName: "PlaylistPic-3", artistName: "Everday Jam", SubartistName: "Music Dance")
                
                HorizontalScollBottonCard( imageName: "PlaylistPic-2", artistName: "Pure Focus", SubartistName: "Music Alternative")
                
                HorizontalScollBottonCard( imageName: "PlaylistPic-1", artistName: "Today's Hits", SubartistName: "Music Hits")
                
                HorizontalScollBottonCard( imageName: "PlaylistPic-3", artistName: "Everday Jam", SubartistName: "Music Dance")
                
                HorizontalScollBottonCard( imageName: "PlaylistPic-4", artistName: "Verified Hits", SubartistName: "Music Pop")
            }
            
        }.padding(.horizontal)
            .scrollClipDisabled()
            //.scrollTargetBehavior(.viewAligned)
    }
}

#Preview {
    HorizontalScrollBottom2()
}
