import SwiftUI
import Kingfisher

struct ArtistView: View {
    @State private var dominantColor: Color = .pink
    
    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            
            ZStack {
                dominantColor
                
                ScrollView {
                    if let artworkURL = URL(string: "https://yt3.googleusercontent.com/_c4JMCiDeaC2RRfShXddOuIV_A7oCL4m1R6-YK-3TDlsYgNQTXwxV0f-TTJrsO1StMt07qW3O6XNPSNt=w544-h544-l90-rj") {
                            KFImage(artworkURL)
                            .resizable()
                            .frame(width: size.width, height: size.width)
                                .onAppear {
                                    loadDominantColor(from: artworkURL)
                                }
                            .overlay {
                                ZStack {
                                    LinearGradient(colors: [dominantColor, dominantColor.opacity(0.2), .clear, .clear, .clear, .clear], startPoint: .bottom, endPoint: .top)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                                    
                                    HStack {
                                        Text("Mac Miller")
                                            .font(.largeTitle)
                                            .bold()
                                        
                                        Spacer()
                                        
                                        Image(systemName: "shuffle")
                                            .padding()
                                            .background(
                                                Circle()
                                                    .foregroundStyle(.black.opacity(0.2))
                                            )
                                            .foregroundStyle(.black)
                                        
                                        Image(systemName: "play.fill")
                                            .padding()
                                            .background(
                                                Circle()
                                                    .foregroundStyle(.black)
                                            )
                                            .foregroundStyle(.white)
                                            .foregroundStyle(.pink.opacity(0.4))
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                                    .padding()
                                }
                            }
                    }
                    
                    ArtistTopSongs()
                    
                    ArtistDiscography()
                }
            }
        }
        .ignoresSafeArea()
    }
    
    func loadDominantColor(from url: URL) {
        KingfisherManager.shared.retrieveImage(with: url) { result in
            switch result {
            case .success(let value):
                if let data = value.data() {
                    Task {
                        let color = await ArtworkDominantColorExtractor.shared
                            .dominantColor(from: data, cacheKey: url.absoluteString)
                        
                        await MainActor.run {
                            self.dominantColor = color
                        }
                    }
                }
            case .failure:
                break
            }
        }
    }
}

#Preview {
    ArtistView()
}
