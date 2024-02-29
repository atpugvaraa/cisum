//
//  Recents.swift
//  cisum
//
//  Created by Aarav Gupta on 18/02/24.
//
import SwiftUI

struct Recents: View {
    var body: some View {
        ScrollView(.horizontal ,showsIndicators: false){
            HStack {
                HorizontalScollBottomCard( imageName: "Artist-9", artistName: "Tame Impala", SubartistName: "Artist")
                .padding(.leading)
                HorizontalScollBottomCard( imageName: "Artist-10", artistName: "The Beatles", SubartistName: "Music Rock")
                HorizontalScollBottomCard( imageName: "Artist-5", artistName: "Frank Ocean", SubartistName: "Music")
                HorizontalScollBottomCard( imageName: "Artist-1", artistName: "Halsey", SubartistName: "")
                HorizontalScollBottomCard( imageName: "Artist-4", artistName: "bro", SubartistName: "Music")
            }
            
        }
    }
}

#Preview {
    Recents()
}
