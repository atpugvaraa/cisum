//
//  cisumSearchChips.swift
//  cisum
//
//  Created by Aarav Gupta on 16/05/25.
//

import SwiftUI

enum SearchTabs: String, CaseIterable {
    case songs = "Songs"
    case albums = "Albums"
    case artists = "Artists"
    case playlists = "Playlists"
}

struct cisumSearchChips: View {
    @State private var search = Search.shared
    
    @State private var offsetObserver = PageOffsetObserver.shared
    
    var body: some View {
        Tabbar(.gray)
            .overlay {
                if let collectionViewBounds = offsetObserver.collectionView?.bounds {
                    GeometryReader { proxy in
                        let width = proxy.size.width
                        let tabCount = CGFloat(SearchTabs.allCases.count)
                        let capsuleWidth = width / tabCount
                        let progress = offsetObserver.offset / collectionViewBounds.width
                        
                        Capsule()
                            .fill(.accent)
                            .overlay {
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .overlay {
                                        Capsule()
                                            .stroke(lineWidth: 2)
                                            .fill(.ultraThinMaterial)
                                            .padding(1)
                                    }
                            }
                            .frame(width: capsuleWidth)
                            .offset(x: progress * capsuleWidth)
                        
                        Tabbar(.white, .semibold)
                            .mask(alignment: .leading) {
                                Capsule()
                                    .frame(width: capsuleWidth)
                                    .offset(x: progress * capsuleWidth)
                            }
                        
                    }
                }
            }
            .clipShape(.capsule)
            .shadow(color: .black.opacity(0.1), radius: 5, x: 5, y: 5)
            .shadow(color: .black.opacity(0.05), radius: 5, x: -5, y: -5)
            .padding(.horizontal, 15)
    }
    
    @ViewBuilder
    func Tabbar(_ tint: Color, _ weight: Font.Weight = .regular) -> some View {
        HStack(spacing: 0) {
            ForEach(SearchTabs.allCases, id: \.rawValue) { tab in
                Text(tab.rawValue)
                    .font(.callout)
                    .fontWeight(weight)
                    .foregroundStyle(tint)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .contentShape(.rect)
                    .onTapGesture {
                        withAnimation(.snappy(duration: 0.3, extraBounce: 0)) {
                            search.activeTab = tab
                        }
                    }
            }
        }
    }
}

#Preview {
    cisumSearchChips()
}

@Observable
class PageOffsetObserver: NSObject {
    static let shared = PageOffsetObserver()
    
    var collectionView: UICollectionView?
    var offset: CGFloat = 0
    private(set) var isObserving: Bool = false
    
    deinit {
        remove()
    }
    
    func observe() {
        // Safe Method
        guard !isObserving else { return }
        collectionView?.addObserver(self, forKeyPath: "contentOffset", context: nil)
        isObserving = true
    }
    
    func remove() {
        isObserving = false
        collectionView?.removeObserver(self, forKeyPath: "contentOffset")
        collectionView = nil
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard keyPath == "contentOffset" else { return }
        if let contentOffset = (object as? UICollectionView)?.contentOffset {
            offset = contentOffset.x
        }
    }
}

struct FindCollectionView: UIViewRepresentable {
    var result: (UICollectionView) -> ()
    
    func makeUIView(context: Context) -> some UIView {
        let view = UIView()
        
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            if let collectionView = view.collectionSuperView {
                result(collectionView)
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        
    }
}

extension UIView {
    var collectionSuperView: UICollectionView? {
        let currentView: UIView? = self
        
        if let view = currentView {
            print("Checking superview: \(type(of: view))")
        }
        
        if let collectionView = superview as? UICollectionView {
            return collectionView
        }
        
        return superview?.collectionSuperView
    }
}
