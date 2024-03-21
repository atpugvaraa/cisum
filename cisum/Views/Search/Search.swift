//
//  Search.swift
//  cisum
//
//  Created by Aarav Gupta on 09/03/24.
//

import SwiftUI

struct Search: View {
  @State private var searchText = ""
  var body: some View {
      NavigationView{
          ScrollView(.vertical){
              VerticalScrollView()
          }.navigationTitle("Search")
      }.searchable(text: $searchText)
  }
}

struct VerticalScrollView: View {
    var body: some View {
        ScrollView(.vertical){


            HStack(spacing:10) {
                VerticalRowCard(Image1: "Cat1", Text1: "Pop")
                VerticalRowCard(Image1: "Cat1", Text1: "Rock")
            }.padding()
            HStack(spacing:10) {
                VerticalRowCard(Image1: "Cat2", Text1: "Pop")
                VerticalRowCard(Image1: "Cat2", Text1: "Rock")
            }.padding()
            HStack(spacing:10) {
                VerticalRowCard(Image1: "Cat3", Text1: "Pop")
                VerticalRowCard(Image1: "Cat3", Text1: "Rock")
            }.padding()
            HStack(spacing:10) {
                VerticalRowCard(Image1: "Cat5", Text1: "Pop")
                VerticalRowCard(Image1: "Cat5", Text1: "Rock")
            }.padding()

            HStack(spacing:10) {
                VerticalRowCard(Image1: "Cat1", Text1: "Pop")
                VerticalRowCard(Image1: "Cat1", Text1: "Rock")
            }.padding()
            HStack(spacing:10) {
                VerticalRowCard(Image1: "Cat2", Text1: "Pop")
                VerticalRowCard(Image1: "Cat2", Text1: "Rock")
            }.padding()
            HStack(spacing:10) {
                VerticalRowCard(Image1: "Cat3", Text1: "Pop")
                VerticalRowCard(Image1: "Cat3", Text1: "Rock")
            }.padding()
            HStack(spacing:10) {
                VerticalRowCard(Image1: "Cat5", Text1: "Pop")
                VerticalRowCard(Image1: "Cat5", Text1: "Rock")
            }.padding()

        }
    }
}

struct VerticalRowCard: View {
    let Image1:String
    let Text1:String
    var body: some View {
        ZStack(alignment:.bottomLeading) {
            Image(Image1)
                .resizable()
                .scaledToFit()


            Text(Text1)
                .fontWeight(.bold)
                .font(.caption2)
                .padding(.leading)
                .padding(.bottom)

        }.cornerRadius(20)
            .shadow(color: .white, radius: 2)
    }
}

#Preview {
    Search()
}
