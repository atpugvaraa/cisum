import SwiftUI
import DesignSystem
import Kingfisher
import Services

struct ContentView: View {
    @State private var palette: ImageColorPalette?
    
    var body: some View {
        VStack {
            CardOpenTransition { isCardExpanded, dismiss in
                VStack {
                    AlbumCover(isCardExpanded: isCardExpanded, palette: $palette)
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
                (palette?.background ?? .black)
                    .frame(height: 1900)
                    .contentShape(.rect)
            }
            .frame(width: 175, height: 175)
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical)
    }
}

struct ExtrusionShape: Shape {
    var offset: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX - offset, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: offset))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: offset, y: rect.maxY))
        path.addLine(to: CGPoint(x: 0, y: rect.maxY - offset))
        path.closeSubpath()
        
        return path
    }
}

struct AlbumCover: View {
    var isCardExpanded: Bool
    @Binding var palette: ImageColorPalette?
    
    var body: some View {
        ZStack {
            Rectangle()
                .foregroundStyle(palette?.background ?? .black)
                .overlay(.black.opacity(0.1))
                .clipShape(ExtrusionShape(offset: 5))
                
            if let url = URL(string: "https://yt3.googleusercontent.com/_c4JMCiDeaC2RRfShXddOuIV_A7oCL4m1R6-YK-3TDlsYgNQTXwxV0f-TTJrsO1StMt07qW3O6XNPSNt=w544-h544-l90-rj") {
                KFImage(url)
                    .resizable()

                    .padding(.trailing, isCardExpanded ? 0 : 5)
                    .padding(.bottom, isCardExpanded ? 0 : 5)
            }
        }
        .task {
            guard let url = URL(string: "https://yt3.googleusercontent.com/_c4JMCiDeaC2RRfShXddOuIV_A7oCL4m1R6-YK-3TDlsYgNQTXwxV0f-TTJrsO1StMt07qW3O6XNPSNt=w36-h36-l90-rj") else { return }
            
            KingfisherManager.shared.retrieveImage(with: url) { result in
                guard case .success(let value) = result,
                      let data = value.image.pngData() else { return }
                
                Task {
                    let extractedPalette = await ImageColorExtractor.shared.extractPalette(from: data, cacheKey: url.absoluteString)
                    await MainActor.run { self.palette = extractedPalette }
                }
            }
        }
    }
}
#if DEBUG
#Preview {
    ContentView()
        .environment(PlaybackServices.preview)
}
#endif
