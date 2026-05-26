//
//  TopArtistSearchResultCard.swift
//  Artists
//
//  Created by Aarav Gupta on 29/04/26.
//

#if os(iOS)
import SwiftUI
import Kingfisher

struct TopArtistSearchResultCard: View {
    let artistName = "Kendrick Lamar"
    let artistImageURL: URL
    let width: CGFloat
    
    var body: some View {
        KFImage(artistImageURL)
            .resizable()
            .scaledToFill()
            .frame(width: width, height: width * 6/7)
            .overlay {
                ZStack {
                    LinearGradient(
                        colors: [.black.opacity(0.5), .clear],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    
                    VStack {
                        Text(artistName)
                            .font(.largeTitle)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        
                        HStack {
                            ForEach(0..<5, id: \.self) { _ in
                                ArtistResultAlbumPreview()
                            }
                        }
                    }
                    .padding(12)
                }
            }
            .clipShape(.rect(cornerRadius: 24))
    }
}

struct ArtistResultAlbumPreview: View {
//    var albumName: String
//    var albumCover: URL
    
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.gray)
            .frame(width: 70, height: 70)
    }
}

#Preview {
    let url = URL(string: "https://yt3.googleusercontent.com/_c4JMCiDeaC2RRfShXddOuIV_A7oCL4m1R6-YK-3TDlsYgNQTXwxV0f-TTJrsO1StMt07qW3O6XNPSNt=w544-h544-l90-rj")!
    
    ScrollView {
        LazyVStack {
            GeometryReader { geo in
                let width = geo.size.width - 32

                TopArtistSearchResultCard(
                    artistImageURL: url,
                    width: width
                )
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(height: (UIScreen.main.bounds.width - 32) * 6/7)
        }
    }
}
#endif
