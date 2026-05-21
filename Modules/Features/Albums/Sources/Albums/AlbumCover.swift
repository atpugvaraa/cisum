//
//  AlbumCover.swift
//  Albums
//
//  Created by Aarav Gupta on 19/05/26.
//

import SwiftUI
import DesignSystem
import Kingfisher
import Services

// MARK: - Album Cover
struct AlbumCover: View {
    var isCardExpanded: Bool
    var viewModel: AlbumViewModel
    
    private let displayURL = URL(string: "https://yt3.googleusercontent.com/_c4JMCiDeaC2RRfShXddOuIV_A7oCL4m1R6-YK-3TDlsYgNQTXwxV0f-TTJrsO1StMt07qW3O6XNPSNt=w544-h544-l90-rj")
    private let paletteURL = URL(string: "https://yt3.googleusercontent.com/_c4JMCiDeaC2RRfShXddOuIV_A7oCL4m1R6-YK-3TDlsYgNQTXwxV0f-TTJrsO1StMt07qW3O6XNPSNt=w36-h36-l90-rj")
    
    var body: some View {
        ZStack {
            Rectangle()
                .foregroundStyle(viewModel.backgroundColor)
                .overlay(isCardExpanded ? .clear : .black.opacity(0.1))
                .clipShape(ExtrusionShape(offset: 5))
                
            if let displayURL {
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
                            Text("Igor")
                                .font(.title)
                                .fontWidth(.expanded)
                                .bold()
                            
                            Text("67 plays")
                                .fontWidth(.expanded)
                                .fontWeight(.semibold)
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
            guard let paletteURL else { return }
            await viewModel.fetchPaletteIfNeeded(from: paletteURL)
        }
    }
}
