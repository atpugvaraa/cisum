//
//  AlbumCover.swift
//  Albums
//
//  Created by Aarav Gupta on 19/05/26.
//

#if os(iOS)
import SwiftUI
import DesignSystem
import Kingfisher
import Services
import Models

// MARK: - Album Cover
public struct AlbumCover: View {
    public var isCardExpanded: Bool
    @Bindable public var viewModel: AlbumViewModel
    public let album: Album
    
    public init(isCardExpanded: Bool, viewModel: AlbumViewModel, album: Album) {
        self.isCardExpanded = isCardExpanded
        self.viewModel = viewModel
        self.album = album
    }
    
    public var body: some View {
        ZStack {
            Rectangle()
                .foregroundStyle(viewModel.backgroundColor)
                .overlay(isCardExpanded ? .clear : .black.opacity(0.1))
                .clipShape(ExtrusionShape(offset: 5))
                
            if let artwork = album.artworkURLString, let displayURL = URL(string: artwork) {
                KFImage(displayURL)
                    .resizable()
                    .padding(.top, isCardExpanded ? 50 : 0)
                    .padding(.trailing, isCardExpanded ? 0 : 5)
                    .padding(.bottom, isCardExpanded ? 0 : 5)
            }
            
            if isCardExpanded {
                LinearGradient(
                    colors: [viewModel.backgroundColor, viewModel.backgroundColor.opacity(0.2), .clear, .clear, .clear, .clear, .clear],
                    startPoint: .bottom, endPoint: .top
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .overlay {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(album.title)
                                .font(.title)
                                .fontWidth(.expanded)
                                .bold()
                            
                            if let year = album.releaseDateString {
                                Text(year)
                                    .fontWidth(.expanded)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding()
                }
                
                LinearGradient(
                    colors: [viewModel.backgroundColor, viewModel.backgroundColor.opacity(0.2), .clear, .clear, .clear, .clear, .clear],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
        .task {
            guard let artwork = album.artworkURLString, let displayURL = URL(string: artwork) else { return }
            let paletteURL = ImageColorExtractor.paletteURL(from: displayURL)
            await viewModel.fetchPaletteIfNeeded(from: paletteURL)
        }
    }
}
#endif
