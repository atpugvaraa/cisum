//
//  ListenNowView.swift
//  cisum
//
//  Created by Aarav Gupta on 18/02/24.
//

import SwiftUI

struct BrowseView: View {
    var body: some View {
        NavigationView {
            
            ScrollView(.vertical , showsIndicators: false)
            {
                browseHorizontal1()
                
                HStack(alignment:.center){
                    Text("Top-Tier Playlists")
                    Image(systemName: "chevron.right").foregroundColor(.secondary)
                    Spacer()
                }.padding(.leading)
                    .font(.title2)
                    .bold()
                    .foregroundColor(.primary)
                
                HorizontalScrollBottom2()
                
                HStack(alignment:.center){
                    Text("Spacial Audio")
                    Image(systemName: "chevron.right").foregroundColor(.secondary)
                    Spacer()
                }.padding(.leading)
                    .font(.title2)
                    .bold()
                    .foregroundColor(.primary)
                
                HorizontalScroll2()
            }
            .navigationTitle("Browse")
        }
    }
}

#Preview {
    BrowseView()
}
