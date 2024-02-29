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
                HorizontalScollBottomCard( imageName: "PlaylistPic-1", artistName: "Today's Hits", SubartistName: "Music Hits")
                .padding(.leading)

                HorizontalScollBottomCard( imageName: "PlaylistPic-4", artistName: "Verified Hits", SubartistName: "Music Pop")
                
                HorizontalScollBottomCard( imageName: "PlaylistPic-2", artistName: "Pure Focus", SubartistName: "Music Alternative")
                
                HorizontalScollBottomCard( imageName: "PlaylistPic-3", artistName: "Everday Jam", SubartistName: "Music Dance")
                
                HorizontalScollBottomCard( imageName: "PlaylistPic-2", artistName: "Pure Focus", SubartistName: "Music Alternative")
                
                HorizontalScollBottomCard( imageName: "PlaylistPic-1", artistName: "Today's Hits", SubartistName: "Music Hits")
                
                HorizontalScollBottomCard( imageName: "PlaylistPic-3", artistName: "Everday Jam", SubartistName: "Music Dance")
                
                HorizontalScollBottomCard( imageName: "PlaylistPic-4", artistName: "Verified Hits", SubartistName: "Music Pop")
            }
        }
    }
}

#Preview {
    HorizontalScrollBottom2()
}
