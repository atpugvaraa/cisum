//
//  Home.swift
//  cisum
//
//  Created by Aarav Gupta on 09/03/24.
//

import SwiftUI

struct Home: View {
    var body: some View {
        NavigationView {
            ScrollView(.vertical , showsIndicators: false) {
                HStack(alignment: .center,spacing: 0 ,content: {
                    Text("Top Picks")
                        .fontWeight(.bold)
                        .font(.title3)
                    Spacer()
                })
                .frame(height: 24)
                .padding(.leading)
                
                TopPicksScroll()
                    .padding(.bottom)
                
                HStack(alignment:.center){
                    Text("Recently Played")
                    Spacer()
                }.padding(.leading)
                    .font(.title3)
                    .bold()
                    .foregroundColor(.primary)
                
                Recents()
                
                HStack(alignment:.center){
                    Text("Try something else")
                    Spacer()
                }
                .padding(.leading)
                .font(.title3)
                .bold()
                .foregroundColor(.primary)
                
                HorizontalScrollBottom2()
                
                HStack(alignment:.center){
                    Text("Made For You")
                    Spacer()
                }
                .padding(.leading)
                .font(.title3)
                .bold()
                .foregroundColor(.primary)
                
                TopPicksScroll().padding(.bottom)
            }
            .navigationTitle("Home")
        }
    }
}

struct TopPicksScroll: View {
  var body: some View {
    ScrollView(.horizontal)
    {
      HStack(spacing: 6) {
        TopPicksCard(
          headLine: "Drake mix",
          imageName: "Image",
          artistName: "Drake, J. Cole, Halsey",
          colorBlock: .blue
        )
        .padding(.leading)

        TopPicksCard(
          headLine: "Featuring you",
          imageName: "Image",
          artistName: "Artist A, Artist B, Artist C",
          colorBlock: .brown
        )

        TopPicksCard(
          headLine: "Custom Headline 2",
          imageName: "Image",
          artistName: "Artist X, Artist Y, Artist Z",
          colorBlock: .red
        )

        TopPicksCard(
          headLine: "Custom Headline 3",
          imageName: "Image",
          artistName: "Custom Artist 1, Custom Artist 2, Custom Artist 3",
          colorBlock: .pink
        )
      }
    }
    .scrollIndicators(.hidden)
  }
}

struct TopPicksCard: View {

    let headLine: String
    let imageName: String
    let artistName: String
    let colorBlock: Color

    var body: some View {
        VStack {
            HStack {
                Text(headLine).font(.caption).foregroundColor(.gray)
                    .padding(.leading, -1)
                Spacer()
            }.frame(width: 260)
            ZStack {
                Rectangle()
                    .foregroundStyle(colorBlock.gradient).opacity(0.6)
                    .frame(width: 260,height: 346)

                VStack {
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 260 ,height: 260)
                    Spacer()

                    Text(artistName)
                        .font(.subheadline)
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.center)
                        .padding([.trailing ,.leading])
                    Spacer()

                }.frame(width: 260,height: 346)
            }.cornerRadius(10)
        }
    }
}

struct Recents: View {
    var body: some View {
        ScrollView(.horizontal ,showsIndicators: false){
            HStack {
                HorizontalScollBottomCard( imageName: "Image", artistName: "Tame Impala", SubartistName: "Artist")
                .padding(.leading)
                HorizontalScollBottomCard( imageName: "Image", artistName: "The Beatles", SubartistName: "Music Rock")
                HorizontalScollBottomCard( imageName: "Image", artistName: "Frank Ocean", SubartistName: "Music")
                HorizontalScollBottomCard( imageName: "Image", artistName: "Halsey", SubartistName: "")
                HorizontalScollBottomCard( imageName: "Image", artistName: "bro", SubartistName: "Music")
            }

        }
    }
}

struct HorizontalScollBottomCard: View {

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

struct HorizontalScrollBottom2: View {
    var body: some View {
        ScrollView(.horizontal ,showsIndicators: false){
            HStack {
                HorizontalScollBottomCard( imageName: "Image", artistName: "Today's Hits", SubartistName: "Music Hits")
                .padding(.leading)

                HorizontalScollBottomCard( imageName: "Image", artistName: "Verified Hits", SubartistName: "Music Pop")

                HorizontalScollBottomCard( imageName: "Image", artistName: "Pure Focus", SubartistName: "Music Alternative")

                HorizontalScollBottomCard( imageName: "Image", artistName: "Everday Jam", SubartistName: "Music Dance")

                HorizontalScollBottomCard( imageName: "Image", artistName: "Pure Focus", SubartistName: "Music Alternative")

                HorizontalScollBottomCard( imageName: "Image", artistName: "Today's Hits", SubartistName: "Music Hits")

                HorizontalScollBottomCard( imageName: "Image", artistName: "Everday Jam", SubartistName: "Music Dance")

                HorizontalScollBottomCard( imageName: "Image", artistName: "Verified Hits", SubartistName: "Music Pop")
            }
        }
    }
}

#Preview {
    Home()
    .preferredColorScheme(.dark)
}
