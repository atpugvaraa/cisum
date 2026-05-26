//
//  AlbumViewModel.swift
//  Albums
//
//  Created by Aarav Gupta on 19/05/26.
//

#if os(iOS)
import SwiftUI
import DesignSystem
import Kingfisher
import Services

// MARK: - State Owner

@MainActor @Observable
public final class AlbumViewModel {
    var palette: ImageColorPalette?
    
    private var hasFetched = false
    
    var backgroundColor: Color {
        palette?.background ?? .black
    }
    
    var titleColor: Color {
        palette?.title ?? .white
    }
    
    func fetchPaletteIfNeeded(from thumbnailURL: URL) async {
        guard !hasFetched else { return }
        hasFetched = true
        
        let data: Data? = await withCheckedContinuation { continuation in
            KingfisherManager.shared.retrieveImage(with: thumbnailURL) { result in
                switch result {
                case .success(let value):
                    continuation.resume(returning: value.image.pngData())
                case .failure:
                    continuation.resume(returning: nil)
                }
            }
        }
        
        guard let data,
              let extracted = await ImageColorExtractor.shared.extractPalette(
                  from: data,
                  cacheKey: thumbnailURL.absoluteString
              )
        else { return }
        
        self.palette = extracted
    }
}
#endif
