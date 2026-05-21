import SwiftUI
import DesignSystem
import Kingfisher
import Services

// MARK: - Root View

struct AlbumCard: View {
    @State private var viewModel = AlbumViewModel()
    
    var body: some View {
        VStack {
            CardOpenTransition(backgroundColor: viewModel.backgroundColor) { isCardExpanded, dismiss in
                VStack {
                    AlbumCover(isCardExpanded: isCardExpanded, viewModel: viewModel)
                        .overlay {
                            if let dismiss {
                                Rectangle()
                                    .foregroundStyle(.clear)
                                    .contentShape(.rect)
                                    .transition(.identity)
                            }
                        }
                }
            } content: { safeArea, dismiss in
                ZStack {
                    Color.clear
                         .frame(height: 1900)
                         .contentShape(.rect)
                    
                    VStack {
                        Text("Hard")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding()
                }
            }
            .frame(width: 175, height: 175)
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical)
    }
}

#if DEBUG
#Preview {
    AlbumCard()
        .environment(PlaybackServices.preview)
}
#endif
