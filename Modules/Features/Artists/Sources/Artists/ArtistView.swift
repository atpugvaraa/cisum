import SwiftUI
import Services
import Kingfisher

struct ArtistView: View {
    @State private var palette: ImageColorPalette?
    
    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            
            ZStack {
                (palette?.background ?? .pink)
                
                ScrollView {
                    if let artworkURL = URL(string: "https://yt3.googleusercontent.com/_c4JMCiDeaC2RRfShXddOuIV_A7oCL4m1R6-YK-3TDlsYgNQTXwxV0f-TTJrsO1StMt07qW3O6XNPSNt=w544-h544-l90-rj") {
                            KFImage(artworkURL)
                            .resizable()

                            .frame(width: size.width, height: size.width)
                            .overlay {
                                ZStack {
                                    LinearGradient(colors: [(palette?.background ?? .pink), (palette?.background ?? .pink).opacity(0.2), .clear, .clear, .clear, .clear], startPoint: .bottom, endPoint: .top)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                                    
                                    HStack {
                                        Text("Mac Miller")
                                            .font(.largeTitle)
                                            .bold()
                                            .foregroundStyle(palette?.title.safeTextColor(over: palette?.background ?? .black) ?? .white)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "shuffle")
                                            .padding()
                                            .background(
                                                Circle()
                                                    .foregroundStyle(.black.opacity(0.2))
                                            )
                                            .foregroundStyle(palette?.background ?? .black)
                                        
                                        Image(systemName: "play.fill")
                                            .padding()
                                            .background(
                                                Circle()
                                                    .foregroundStyle(palette?.title.safeTextColor(over: palette?.background ?? .black) ?? .black)
                                            )
                                            .foregroundStyle(palette?.background ?? .white)
                                            .foregroundStyle((palette?.dominant ?? .pink).opacity(0.4))
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                                    .padding()
                                }
                            }
                            .task {
                                let tinyURL = ImageColorExtractor.paletteURL(from: artworkURL)
                                KingfisherManager.shared.retrieveImage(with: tinyURL) { result in
                                    guard case .success(let value) = result,
                                          let data = value.image.pngData() else { return }
                                    
                                    Task {
                                        let extractedPalette = await ImageColorExtractor.shared.extractPalette(from: data, cacheKey: artworkURL.absoluteString)
                                        await MainActor.run { self.palette = extractedPalette }
                                    }
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
}
#if DEBUG
#Preview {
    ArtistView()
        .environment(PlaybackServices.preview)
}
#endif
