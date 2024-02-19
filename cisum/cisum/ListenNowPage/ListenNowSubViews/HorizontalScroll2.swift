//
//  HorizontalScroll2.swift
//  cisum
//
//  Created by Aarav Gupta on 18/02/24.
//
import SwiftUI

struct HorizontalScroll2: View {
    var body: some View {
        ScrollView(.horizontal ,showsIndicators: false){
            HStack {
                HorizontalScollBottonCard( imageName: "Artist-9", artistName: "Tame Impala", SubartistName: "Artist")
                HorizontalScollBottonCard( imageName: "Artist-10", artistName: "The Beatles", SubartistName: "Music Rock")
                HorizontalScollBottonCard( imageName: "Artist-5", artistName: "Frank Ocean", SubartistName: "Music")
                HorizontalScollBottonCard( imageName: "Artist-1", artistName: "Halsey", SubartistName: "")
                HorizontalScollBottonCard( imageName: "Artist-4", artistName: "bro", SubartistName: "Music")
            }
            
        }.padding(.leading)
    }
}

#Preview {
    HorizontalScroll2()
}
