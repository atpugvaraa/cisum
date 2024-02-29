//
//  HomeView.swift
//  cisum
//
//  Created by Aarav Gupta on 18/02/24.
//
import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationView {    
            
            ScrollView(.vertical , showsIndicators: false)
          {
            HStack(alignment: .center,spacing: 0 ,content: {
              Text("Top Picks").fontWeight(.bold).font(.title3)
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
            }.padding(.leading)
              .font(.title3)
              .bold()
              .foregroundColor(.primary)

            TopPicksScroll().padding(.bottom)
          }
          .navigationTitle("Home")
        }
    }
}

#Preview {
    HomeView()
}
