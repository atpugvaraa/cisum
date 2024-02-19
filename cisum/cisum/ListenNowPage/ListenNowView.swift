//
//  ListenNowView.swift
//  cisum
//
//  Created by Aarav Gupta on 18/02/24.
//
import SwiftUI

struct ListenNowView: View {
    var body: some View {
        NavigationView {    
            
            ScrollView(.vertical , showsIndicators: false)
            {
                HStack(alignment: .center,spacing: 0 ,content: {
                    Text("Top Picks").fontWeight(.bold).font(.title3)
                    Spacer()
                }).frame(height: 24).padding(.leading)
                
                HorizontalScroll1().padding(.bottom)
                
                HStack(alignment:.center){
                    Text("Recently Played")
                    Image(systemName: "chevron.right")
                    Spacer()
                }.padding(.leading)
                    .font(.title2)
                    .bold()
                    .foregroundColor(.primary)
                
                HorizontalScroll2()
                
                HStack(alignment:.center){
                    Text("Relaxing 🎶")
                    Image(systemName: "chevron.right")
                    Spacer()
                }.padding(.leading)
                    .font(.title2)
                    .bold()
                    .foregroundColor(.primary)
                
                HorizontalScrollBottom2()
                
                HorizontalScroll1().padding(.bottom)
            }
            .navigationTitle("Listen Now")
        }
    }
}

#Preview {
    ListenNowView()
}
