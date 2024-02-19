//
//  HorizontalScroll1.swift
//  cisum
//
//  Created by Aarav Gupta on 18/02/24.
//
import SwiftUI

struct HorizontalScroll1: View {
    var body: some View {
        ScrollView(.horizontal)
        {
            HStack(spacing: 10) {
                HorizontalScrollTopCard(
                    headLine: "Drake mix",
                    imageName: "Artist-8",
                    artistName: "Drake, J. Cole, Halsey",
                    colorBlock: .blue
                )
                
                HorizontalScrollTopCard(
                    headLine: "Featuring you",
                    imageName: "Artist-7",
                    artistName: "Artist A, Artist B, Artist C",
                    colorBlock: .brown
                )

                HorizontalScrollTopCard(
                    headLine: "Custom Headline 2",
                    imageName: "Artist-5",
                    artistName: "Artist X, Artist Y, Artist Z",
                    colorBlock: .red
                )

                HorizontalScrollTopCard(
                    headLine: "Custom Headline 3",
                    imageName: "Artist-6",
                    artistName: "Custom Artist 1, Custom Artist 2, Custom Artist 3",
                    colorBlock: .pink
                )
            }
        }.padding(.leading)
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }
}

#Preview {
    HorizontalScroll1()
}
