//
//  HorizontalScollBottonCard.swift
//  cisum
//
//  Created by Aarav Gupta on 18/02/24.
//
import SwiftUI

struct HorizontalScollBottonCard: View {
    
    let imageName: String
    let artistName: String
    let SubartistName: String?
    
    
    var body: some View {
        VStack(alignment: .leading) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 170  ,height: 170)
                .cornerRadius(10)
            
            VStack(alignment: .leading) {
                Text(artistName)
                    .font(.caption)
                    .foregroundStyle(Color.primary)
                
                Text(SubartistName ?? "")
                    .font(.caption)
                    .foregroundStyle(Color.gray)
            }.padding(.leading ,10)
        }.frame(width: 170,height: 215)
    }
}


#Preview {
    HorizontalScollBottonCard( imageName: "Artist-1", artistName: "Halsey", SubartistName: "Apple Music")
}
